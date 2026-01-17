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

// Spring pendulum - oscillates in angle AND length
vec3 springPendulum(float time, float idx, float baseFreq, float bass, float mid) {
    // Angular oscillation
    float angFreq = baseFreq + idx * 0.08;
    float angle = 0.7 * sin(time * angFreq);

    // Length oscillation (spring bounce) - faster frequency
    float lenFreq = angFreq * 2.5 + mid * 0.5;
    float lenOsc = 0.15 * sin(time * lenFreq + bass * PI);

    // Damping factor for realism
    float damp = 0.9 + 0.1 * cos(time * 0.1);

    return vec3(angle * damp, lenOsc, lenFreq);
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

    vec3 color = vec3(0.02, 0.03, 0.04);

    // Parameters
    float numSprings = 10.0 + energy * 5.0;
    float baseLength = 0.35;
    float baseFreq = 0.6 + treble * 0.3;
    float anchorY = 0.4;

    // Anchor bar
    float barDist = abs(uv.y - anchorY);
    if (abs(uv.x) < 0.75) {
        float bar = exp(-barDist * 60.0) * 0.25;
        color += vec3(0.35, 0.35, 0.4) * bar;
    }

    // Draw spring pendulums
    for (float i = 0.0; i < 15.0; i += 1.0) {
        if (i >= numSprings) break;

        float x = (i / numSprings - 0.5) * 1.4;
        vec2 anchor = vec2(x, anchorY);

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

        vec3 springState = springPendulum(time, i, baseFreq, bass, mid);
        float angle = springState.x * (0.8 + bandValue * 0.4);
        float lenOffset = springState.y * (0.8 + bandValue * 0.5);

        float len = baseLength + lenOffset;
        vec2 bobPos = anchor + len * vec2(sin(angle), -cos(angle));

        // Draw coiled spring
        float coils = 8.0;
        float coilWidth = 0.015 + bandValue * 0.005;
        vec2 springDir = normalize(bobPos - anchor);
        vec2 springPerp = vec2(-springDir.y, springDir.x);

        for (float c = 0.0; c < 1.0; c += 0.03) {
            vec2 basePoint = mix(anchor, bobPos, c);
            // Coil offset
            float coilPhase = c * coils * TAU;
            float coilAmp = coilWidth * sin(c * PI);  // Narrower at ends
            vec2 coilOffset = springPerp * sin(coilPhase) * coilAmp;
            vec2 coilPoint = basePoint + coilOffset;

            float coilDist = length(uv - coilPoint);
            float coilLine = exp(-coilDist * 120.0) * 0.25;

            // Spring color - metallic
            vec3 springColor = mix(vec3(0.5, 0.5, 0.6), vec3(0.8, 0.8, 0.9), sin(coilPhase) * 0.5 + 0.5);
            color += springColor * coilLine;
        }

        // Draw bob
        float bobRadius = 0.025 + beat * 0.01;
        float bobDist = length(uv - bobPos);
        float bob = smoothstep(bobRadius, bobRadius * 0.4, bobDist);
        float bobGlow = exp(-bobDist * 30.0) * 0.5;

        // Bob color based on spring state (stretched = warm, compressed = cool)
        float stretch = (len - baseLength) / 0.15;
        float hue = 0.6 - stretch * 0.4;  // Blue when compressed, orange when stretched
        vec3 bobColor = hsv2rgb(vec3(hue, 0.6, 0.9));

        color += bobColor * (bob + bobGlow);

        // Bounce trail
        for (float t = 1.0; t < 10.0; t += 1.0) {
            float pastTime = time - t * 0.02;
            vec3 pastState = springPendulum(pastTime, i, baseFreq, bass, mid);
            float pastLen = baseLength + pastState.y * (0.8 + bandValue * 0.5);
            float pastAngle = pastState.x * (0.8 + bandValue * 0.4);
            vec2 pastBob = anchor + pastLen * vec2(sin(pastAngle), -cos(pastAngle));

            float trailDist = length(uv - pastBob);
            float trailGlow = exp(-trailDist * 50.0) * (1.0 - t / 10.0) * 0.1;
            color += bobColor * trailGlow;
        }

        // Anchor point
        float anchorDist = length(uv - anchor);
        color += vec3(0.4, 0.4, 0.5) * exp(-anchorDist * 60.0) * 0.3;
    }

    // Beat bounce effect
    color *= 1.0 + beat * 0.25;

    // Vignette
    float vig = 1.0 - length(uv) * 0.25;
    color *= smoothstep(0.0, 1.0, vig);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
