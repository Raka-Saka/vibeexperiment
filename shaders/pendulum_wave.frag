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

// Wave machine rod angle - traveling wave
float waveAngle(float idx, float total, float time, float amplitude, float waveSpeed, float waveLength) {
    // Traveling sine wave along the rods
    float phase = idx / total * TAU * waveLength - time * waveSpeed;
    return amplitude * sin(phase);
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

    vec3 color = vec3(0.02, 0.025, 0.04);

    // Wave machine parameters
    float numRods = 20.0 + energy * 10.0;
    float rodLength = 0.3 + bass * 0.1;
    float amplitude = 0.6 + mid * 0.3;
    float waveSpeed = 2.0 + treble * 1.5;
    float waveLength = 2.0 + energy * 1.0;  // Number of complete waves visible

    // Central axis
    float axisY = 0.0;
    float axisWidth = 0.9;

    // Draw central axis/spine
    if (abs(uv.y - axisY) < 0.02 && abs(uv.x) < axisWidth) {
        float axisDist = abs(uv.y - axisY);
        float axis = exp(-axisDist * 80.0) * 0.3;
        color += vec3(0.3, 0.3, 0.35) * axis;
    }

    // Draw wave rods
    for (float i = 0.0; i < 30.0; i += 1.0) {
        if (i >= numRods) break;

        float x = (i / numRods - 0.5) * axisWidth * 2.0;
        vec2 pivot = vec2(x, axisY);

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

        // Wave angle - smooth traveling wave
        float angle = waveAngle(i, numRods, time, amplitude * (0.8 + bandValue * 0.4), waveSpeed, waveLength);

        // Rod extends both up and down from pivot
        float len = rodLength * (0.85 + bandValue * 0.25);
        vec2 topPos = pivot + len * vec2(sin(angle), cos(angle));
        vec2 bottomPos = pivot - len * vec2(sin(angle), cos(angle));

        // Draw rod with smooth end fades
        for (float s = -1.0; s <= 1.0; s += 0.08) {
            vec2 rodPoint = pivot + len * s * vec2(sin(angle), cos(angle));
            float rodDist = length(uv - rodPoint);

            // Fade at rod ends to prevent abrupt cutoff
            float endFade = 1.0 - smoothstep(0.7, 1.0, abs(s));
            float rodLine = exp(-rodDist * 100.0) * 0.3 * endFade;

            // Color varies along rod
            float hue = 0.55 + s * 0.1 + i / numRods * 0.15;
            vec3 rodColor = hsv2rgb(vec3(hue, 0.5, 0.8));
            color += rodColor * rodLine;
        }

        // End caps
        float capRadius = 0.015 + beat * 0.005;

        float topDist = length(uv - topPos);
        float topCap = smoothstep(capRadius, capRadius * 0.3, topDist);
        float topGlow = exp(-topDist * 40.0) * 0.4;

        float bottomDist = length(uv - bottomPos);
        float bottomCap = smoothstep(capRadius, capRadius * 0.3, bottomDist);
        float bottomGlow = exp(-bottomDist * 40.0) * 0.4;

        // Colors
        vec3 topColor = hsv2rgb(vec3(0.6 + i / numRods * 0.2, 0.6, 0.9));
        vec3 bottomColor = hsv2rgb(vec3(0.4 + i / numRods * 0.2, 0.6, 0.9));

        color += topColor * (topCap + topGlow);
        color += bottomColor * (bottomCap + bottomGlow);

        // Pivot point
        float pivotDist = length(uv - pivot);
        float pivotDot = exp(-pivotDist * 80.0) * 0.2;
        color += vec3(0.4, 0.4, 0.5) * pivotDot;
    }

    // Wave envelope visualization
    float envelopeY = 0.0;
    for (float i = 0.0; i < numRods; i += 1.0) {
        float x = (i / numRods - 0.5) * axisWidth * 2.0;
        if (abs(uv.x - x) < 0.02) {
            float angle = waveAngle(i, numRods, time, amplitude, waveSpeed, waveLength);
            envelopeY = sin(angle) * rodLength * 0.5;
        }
    }

    // Beat pulse along wave
    float wavePulse = exp(-length(uv) * 2.0) * beat * 0.2;
    color += vec3(0.3, 0.35, 0.5) * wavePulse;

    // Vignette
    float vig = 1.0 - length(uv) * 0.2;
    color *= smoothstep(0.0, 1.0, vig);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
