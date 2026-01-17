#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform float uTime;
uniform float uBass;
uniform float uMid;
uniform float uTreble;
uniform float uEnergy;
uniform float uBeat;
uniform float uBand0;
uniform float uBand1;
uniform float uBand2;
uniform float uBand3;
uniform float uBand4;
uniform float uBand5;
uniform float uBand6;
uniform float uBand7;

out vec4 fragColor;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Pendulum angle calculation
float pendulumAngle(float idx, float total, float time, float amplitude, float baseFreq) {
    float period = 1.0 / (baseFreq + idx * 0.08);
    return amplitude * sin(TAU * time / period);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 center = uSize * 0.5;
    vec2 uv = (fragCoord - center) / min(uSize.x, uSize.y);

    float time = uTime;
    float bass = uBass;
    float mid = uMid;
    float treble = uTreble;
    float energy = uEnergy;
    float beat = uBeat;

    // Dark background
    vec3 color = vec3(0.02, 0.02, 0.04);

    // Parameters
    float numPendulums = 16.0 + energy * 8.0;
    float pendulumLength = 0.35 + bass * 0.1;
    float amplitude = 0.6 + mid * 0.3;
    float baseFreq = 0.25 + treble * 0.2;

    // Center ring
    float centerRadius = 0.08;
    float ringDist = abs(length(uv) - centerRadius);
    float ring = exp(-ringDist * 60.0) * 0.4;
    color += vec3(0.3, 0.3, 0.4) * ring;

    // Draw pendulums radiating from center
    for (float i = 0.0; i < 24.0; i += 1.0) {
        if (i >= numPendulums) break;

        // Angle around the circle
        float baseAngle = i / numPendulums * TAU;

        // Swing angle
        float swingAngle = pendulumAngle(i, numPendulums, time, amplitude, baseFreq);

        // Audio band modulation
        float bandIdx = mod(i, 8.0);
        float bandValue = 0.0;
        if (bandIdx < 1.0) bandValue = uBand0;
        else if (bandIdx < 2.0) bandValue = uBand1;
        else if (bandIdx < 3.0) bandValue = uBand2;
        else if (bandIdx < 4.0) bandValue = uBand3;
        else if (bandIdx < 5.0) bandValue = uBand4;
        else if (bandIdx < 6.0) bandValue = uBand5;
        else if (bandIdx < 7.0) bandValue = uBand6;
        else bandValue = uBand7;

        // Pendulum length varies with audio
        float len = pendulumLength * (0.8 + bandValue * 0.4);

        // Anchor point on the ring
        vec2 anchor = centerRadius * vec2(cos(baseAngle), sin(baseAngle));

        // Bob swings perpendicular to radial direction
        float bobAngle = baseAngle + swingAngle;
        vec2 bobPos = anchor + len * vec2(cos(bobAngle), sin(bobAngle));

        // Draw bob
        float bobRadius = 0.02 + beat * 0.008;
        float bobDist = length(uv - bobPos);
        float bob = smoothstep(bobRadius, bobRadius * 0.3, bobDist);
        float glow = exp(-bobDist * 25.0) * 0.5;

        // Color
        float hue = i / numPendulums + time * 0.02;
        float sat = 0.6 + bandValue * 0.3;
        float val = 0.8 + beat * 0.2;
        vec3 bobColor = hsv2rgb(vec3(hue, sat, val));

        // Trail with smooth end fade
        for (float t = 1.0; t < 8.0; t += 1.0) {
            float pastTime = time - t * 0.025;
            float pastSwing = pendulumAngle(i, numPendulums, pastTime, amplitude, baseFreq);
            float pastBobAngle = baseAngle + pastSwing;
            vec2 pastBobPos = anchor + len * vec2(cos(pastBobAngle), sin(pastBobAngle));

            float trailDist = length(uv - pastBobPos);
            float normalizedT = t / 8.0;
            float endFade = 1.0 - smoothstep(0.6, 1.0, normalizedT);
            float trailGlow = exp(-trailDist * 40.0) * (1.0 - normalizedT) * endFade * 0.15;
            color += bobColor * trailGlow;
        }

        // Draw string
        vec2 toAnchor = anchor - uv;
        vec2 toBob = bobPos - anchor;
        float stringProj = dot(uv - anchor, normalize(toBob));
        if (stringProj > 0.0 && stringProj < len) {
            vec2 closestOnString = anchor + normalize(toBob) * stringProj;
            float stringDist = length(uv - closestOnString);
            float stringLine = exp(-stringDist * 150.0) * 0.1;
            color += vec3(0.4, 0.4, 0.5) * stringLine;
        }

        color += bobColor * (bob + glow);
    }

    // Center glow on beat
    float centerGlow = exp(-length(uv) * 8.0) * beat * 0.5;
    color += vec3(0.4, 0.3, 0.5) * centerGlow;

    // Vignette
    float vig = 1.0 - length(uv) * 0.3;
    color *= smoothstep(0.0, 1.0, vig);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
