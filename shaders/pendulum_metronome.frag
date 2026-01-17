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

// Metronome angle - inverted pendulum
float metronomeAngle(float idx, float total, float time, float amplitude, float baseFreq) {
    // Each metronome has slightly different frequency - they sync and desync
    float freq = baseFreq * (1.0 + idx * 0.02);
    return amplitude * sin(TAU * time * freq);
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

    vec3 color = vec3(0.03, 0.02, 0.04);

    // Metronome parameters
    float numMetronomes = 8.0 + energy * 4.0;
    float armLength = 0.35 + bass * 0.08;
    float amplitude = 0.4 + mid * 0.25;
    float baseFreq = 0.8 + treble * 0.4;

    // Base platform
    float baseY = -0.3;
    float baseDist = abs(uv.y - baseY);
    if (uv.y < baseY + 0.02) {
        float base = exp(-baseDist * 40.0) * 0.3;
        color += vec3(0.3, 0.25, 0.2) * base;
    }

    // Draw metronomes
    for (float i = 0.0; i < 12.0; i += 1.0) {
        if (i >= numMetronomes) break;

        float x = (i / numMetronomes - 0.5) * 1.4;
        vec2 pivot = vec2(x, baseY);

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

        float angle = metronomeAngle(i, numMetronomes, time, amplitude * (0.8 + bandValue * 0.4), baseFreq);

        // Arm goes UP (inverted pendulum)
        float len = armLength * (0.9 + bandValue * 0.2);
        vec2 tipPos = pivot + len * vec2(sin(angle), cos(angle));

        // Draw metronome body (triangular base)
        float bodyHeight = 0.08;
        float bodyWidth = 0.03;
        vec2 toUV = uv - pivot;
        if (toUV.y > 0.0 && toUV.y < bodyHeight) {
            float widthAtY = bodyWidth * (1.0 - toUV.y / bodyHeight);
            if (abs(toUV.x) < widthAtY) {
                color += vec3(0.25, 0.2, 0.15) * 0.8;
            }
        }

        // Draw arm
        vec2 armDir = normalize(tipPos - pivot);
        for (float s = 0.0; s < 1.0; s += 0.04) {
            vec2 armPoint = pivot + (tipPos - pivot) * s;
            float armDist = length(uv - armPoint);
            float armLine = exp(-armDist * 100.0) * 0.2;
            color += vec3(0.5, 0.4, 0.3) * armLine;
        }

        // Draw weight (moves along arm)
        float weightPos = 0.7 + bandValue * 0.2;
        vec2 weightCenter = pivot + (tipPos - pivot) * weightPos;
        float weightDist = length(uv - weightCenter);
        float weightSize = 0.025 + beat * 0.008;
        float weight = smoothstep(weightSize, weightSize * 0.5, weightDist);
        float weightGlow = exp(-weightDist * 30.0) * 0.4;

        // Draw tip
        float tipDist = length(uv - tipPos);
        float tipSize = 0.015;
        float tip = smoothstep(tipSize, tipSize * 0.3, tipDist);
        float tipGlow = exp(-tipDist * 40.0) * 0.3;

        // Colors
        float hue = i / numMetronomes * 0.3 + 0.05 + time * 0.01;
        vec3 metalColor = vec3(0.7, 0.6, 0.4);
        vec3 accentColor = hsv2rgb(vec3(hue, 0.6, 0.9));

        color += metalColor * weight;
        color += accentColor * (weightGlow + tipGlow);
        color += vec3(0.8, 0.7, 0.5) * tip;

        // Tick flash at extremes
        if (abs(angle) > amplitude * 0.9) {
            float flash = exp(-tipDist * 20.0) * 0.3 * beat;
            color += accentColor * flash;
        }
    }

    // Sync indicator - glow when metronomes align
    float syncAmount = 0.0;
    for (float i = 0.0; i < 8.0; i += 1.0) {
        float angle = metronomeAngle(i, numMetronomes, time, amplitude, baseFreq);
        syncAmount += cos(angle * 2.0);
    }
    syncAmount = max(0.0, syncAmount / 8.0 - 0.5) * 2.0;
    color += vec3(0.4, 0.3, 0.5) * syncAmount * 0.3;

    // Vignette
    float vig = 1.0 - length(uv) * 0.25;
    color *= smoothstep(0.0, 1.0, vig);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
