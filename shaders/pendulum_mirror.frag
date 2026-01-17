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

// Smooth pendulum angle
float pendulumAngle(float idx, float total, float time, float amplitude, float baseFreq) {
    float period = 1.0 / (baseFreq + idx * 0.1);
    return amplitude * sin(TAU * time / period);
}

// Draw a single pendulum and return its color contribution
vec3 drawPendulum(vec2 uv, vec2 anchor, float angle, float len, float bobRadius,
                  vec3 bobColor, float trailFade, float time, float idx,
                  float numPendulums, float amplitude, float baseFreq, bool isReflection) {
    vec3 result = vec3(0.0);

    vec2 bobPos = anchor + len * vec2(sin(angle), -cos(angle));

    // Trail with smooth end fade
    for (float t = 1.0; t < 12.0; t += 1.0) {
        float pastTime = time - t * 0.02;
        float pastAngle = pendulumAngle(idx, numPendulums, pastTime, amplitude, baseFreq);
        vec2 pastBobPos = anchor + len * vec2(sin(pastAngle), -cos(pastAngle));

        float trailDist = length(uv - pastBobPos);
        float normalizedT = t / 12.0;
        float fade = pow(1.0 - normalizedT, 1.5);
        float endFade = 1.0 - smoothstep(0.6, 1.0, normalizedT);
        float trailGlow = exp(-trailDist * 45.0) * fade * endFade * trailFade;
        result += bobColor * trailGlow;
    }

    // String
    vec2 toAnchor = anchor - uv;
    vec2 toBob = bobPos - anchor;
    float stringProj = dot(uv - anchor, normalize(toBob));
    if (stringProj > 0.0 && stringProj < len) {
        vec2 closestOnString = anchor + normalize(toBob) * stringProj;
        float stringDist = length(uv - closestOnString);
        float stringLine = exp(-stringDist * 150.0) * (isReflection ? 0.08 : 0.12);
        result += vec3(0.4, 0.4, 0.5) * stringLine;
    }

    // Bob
    float bobDist = length(uv - bobPos);
    float bob = smoothstep(bobRadius, bobRadius * 0.4, bobDist);
    float glow = exp(-bobDist * 30.0) * (isReflection ? 0.35 : 0.5);

    result += bobColor * (bob + glow);

    return result;
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

    // Gradient background
    float bgGrad = uv.y * 0.3 + 0.5;
    vec3 color = mix(vec3(0.02, 0.025, 0.04), vec3(0.04, 0.03, 0.05), bgGrad);

    // Parameters
    float numPendulums = 10.0 + energy * 5.0;
    float pendulumLength = 0.28 + bass * 0.08;
    float amplitude = 0.7 + mid * 0.3;
    float baseFreq = 0.3 + treble * 0.2;

    // Mirror line position (horizontal center)
    float mirrorY = 0.0;

    // Draw mirror line with subtle glow
    float mirrorDist = abs(uv.y - mirrorY);
    float mirrorLine = exp(-mirrorDist * 50.0) * 0.25;
    float mirrorGlow = exp(-mirrorDist * 15.0) * 0.1;
    color += vec3(0.5, 0.5, 0.6) * mirrorLine;
    color += vec3(0.3, 0.35, 0.45) * mirrorGlow;

    // Anchor positions
    float anchorY = 0.38;
    float reflectAnchorY = -anchorY;  // Mirrored below

    // Anchor bar (top)
    float barDist = abs(uv.y - anchorY);
    if (abs(uv.x) < 0.75) {
        float bar = exp(-barDist * 70.0) * 0.2;
        color += vec3(0.35, 0.35, 0.4) * bar;
    }

    // Reflected anchor bar (bottom) - fainter
    float reflectBarDist = abs(uv.y - reflectAnchorY);
    if (abs(uv.x) < 0.75) {
        float reflectBar = exp(-reflectBarDist * 70.0) * 0.12;
        color += vec3(0.25, 0.25, 0.3) * reflectBar;
    }

    // Draw pendulums
    for (float i = 0.0; i < 15.0; i += 1.0) {
        if (i >= numPendulums) break;

        float x = (i / numPendulums - 0.5) * 1.4;

        // Audio band
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

        float angle = pendulumAngle(i, numPendulums, time, amplitude * (0.8 + bandValue * 0.4), baseFreq);
        float len = pendulumLength * (0.85 + bandValue * 0.25);
        float bobRadius = 0.022 + beat * 0.008;

        // Colors
        float hue = i / numPendulums * 0.6 + time * 0.02;
        vec3 bobColor = hsv2rgb(vec3(hue, 0.65, 0.9));
        vec3 reflectColor = hsv2rgb(vec3(hue + 0.02, 0.5, 0.7));  // Slightly different, muted

        // Real pendulum (top)
        vec2 anchor = vec2(x, anchorY);
        color += drawPendulum(uv, anchor, angle, len, bobRadius, bobColor, 0.12,
                             time, i, numPendulums, amplitude * (0.8 + bandValue * 0.4), baseFreq, false);

        // Reflected pendulum (bottom) - inverted angle, mirrored position
        vec2 reflectAnchor = vec2(x, reflectAnchorY);
        float reflectAngle = -angle;  // Mirror the swing
        color += drawPendulum(uv, reflectAnchor, reflectAngle, len, bobRadius * 0.9, reflectColor, 0.08,
                             time, i, numPendulums, amplitude * (0.8 + bandValue * 0.4), baseFreq, true);
    }

    // Beat ripple from mirror
    float rippleDist = abs(uv.y - mirrorY);
    float ripple = sin(rippleDist * 30.0 - time * 5.0) * 0.5 + 0.5;
    ripple *= exp(-rippleDist * 8.0) * beat * 0.15;
    color += vec3(0.4, 0.45, 0.6) * ripple;

    // Vignette
    float vig = 1.0 - length(uv) * 0.2;
    color *= smoothstep(0.0, 1.0, vig);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
