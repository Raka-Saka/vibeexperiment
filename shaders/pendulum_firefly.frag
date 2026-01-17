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

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Smooth pendulum angle - no jumps
float pendulumAngle(float idx, float total, float time, float amplitude, float baseFreq) {
    float period = 1.0 / (baseFreq + idx * 0.1);
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

    // Deep dark background for firefly effect
    vec3 color = vec3(0.01, 0.015, 0.03);

    // Parameters - smooth, continuous values
    float numFireflies = 12.0 + energy * 6.0;
    float pendulumLength = 0.4 + bass * 0.15;
    float amplitude = 0.7 + mid * 0.3;
    float baseFreq = 0.25 + treble * 0.15;
    float anchorY = 0.4;

    // Very subtle anchor line
    float barDist = abs(uv.y - anchorY);
    float bar = exp(-barDist * 100.0) * 0.1;
    color += vec3(0.15, 0.15, 0.2) * bar * (abs(uv.x) < 0.8 ? 1.0 : 0.0);

    // Draw firefly pendulums
    for (float i = 0.0; i < 18.0; i += 1.0) {
        if (i >= numFireflies) break;

        float x = (i / numFireflies - 0.5) * 1.5;
        vec2 anchor = vec2(x, anchorY);

        // Audio band for this firefly
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

        // Smooth angle calculation
        float angle = pendulumAngle(i, numFireflies, time, amplitude, baseFreq);
        float modAmplitude = amplitude * (0.8 + bandValue * 0.4);

        // Firefly position
        float len = pendulumLength * (0.85 + bandValue * 0.25);
        vec2 fireflyPos = anchor + len * vec2(sin(angle), -cos(angle));

        // Firefly glow color - warm yellows and greens
        float hue = 0.15 + i / numFireflies * 0.1 + sin(time * 0.5 + i) * 0.05;
        float sat = 0.7 + bandValue * 0.2;
        float val = 0.9 + beat * 0.1;
        vec3 fireflyColor = hsv2rgb(vec3(hue, sat, val));

        // Pulsing brightness (like real fireflies)
        float pulse = 0.6 + 0.4 * sin(time * 3.0 + i * 1.5);
        pulse *= (0.7 + bandValue * 0.5);

        // Long glowing trail
        for (float t = 0.0; t < 25.0; t += 1.0) {
            float pastTime = time - t * 0.02;
            float pastAngle = pendulumAngle(i, numFireflies, pastTime, amplitude, baseFreq);
            vec2 pastPos = anchor + len * vec2(sin(pastAngle), -cos(pastAngle));

            float trailDist = length(uv - pastPos);
            float normalizedT = t / 25.0;
            float fade = pow(1.0 - normalizedT, 1.5);  // Smooth exponential fade
            // Extra smooth fade at end to prevent abrupt cutoff
            float endFade = 1.0 - smoothstep(0.7, 1.0, normalizedT);
            float trailGlow = exp(-trailDist * 35.0) * fade * endFade * 0.12 * pulse;

            // Trail color fades to cooler
            float trailHue = hue + t * 0.008;
            vec3 trailColor = hsv2rgb(vec3(trailHue, sat * 0.8, val * fade * endFade));
            color += trailColor * trailGlow;
        }

        // Main firefly glow - soft, large
        float dist = length(uv - fireflyPos);
        float outerGlow = exp(-dist * 8.0) * 0.3 * pulse;
        float innerGlow = exp(-dist * 25.0) * 0.6 * pulse;
        float core = exp(-dist * 60.0) * pulse;

        color += fireflyColor * 0.3 * outerGlow;
        color += fireflyColor * innerGlow;
        color += vec3(1.0, 0.95, 0.8) * core;  // Bright white-yellow core

        // Very faint string (almost invisible)
        vec2 toAnchor = anchor - uv;
        vec2 toBob = fireflyPos - anchor;
        float stringProj = dot(uv - anchor, normalize(toBob));
        if (stringProj > 0.0 && stringProj < len) {
            vec2 closestOnString = anchor + normalize(toBob) * stringProj;
            float stringDist = length(uv - closestOnString);
            float stringLine = exp(-stringDist * 200.0) * 0.03;
            color += vec3(0.2, 0.2, 0.25) * stringLine;
        }
    }

    // Ambient glow on beat
    float ambientGlow = exp(-length(uv) * 2.0) * beat * 0.15;
    color += vec3(0.2, 0.25, 0.15) * ambientGlow;

    // Very subtle vignette
    float vig = 1.0 - length(uv) * 0.15;
    color *= smoothstep(0.0, 1.0, vig);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
