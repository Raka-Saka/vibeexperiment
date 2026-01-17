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

// Lissajous curve position
vec2 lissajous(float t, float freqX, float freqY, float phaseX, float phaseY, float ampX, float ampY) {
    return vec2(
        ampX * sin(freqX * t + phaseX),
        ampY * sin(freqY * t + phaseY)
    );
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

    vec3 color = vec3(0.02, 0.03, 0.05);

    // Lissajous parameters - frequency ratios create different patterns
    // Classic ratios: 1:2, 2:3, 3:4, etc.
    float baseFreq = 1.5 + energy * 0.5;

    // Audio-reactive frequency ratios
    float freqX = baseFreq * (1.0 + bass * 0.3);
    float freqY = baseFreq * (2.0 + mid * 0.5);  // 1:2 ratio base

    // Phase shift creates rotation of pattern
    float phaseX = time * 0.3;
    float phaseY = time * 0.2 + treble * PI;

    // Amplitude
    float ampX = 0.35 + uBand0 * 0.1;
    float ampY = 0.35 + uBand4 * 0.1;

    // Current pendulum position
    vec2 pendulumPos = lissajous(time * 2.0, freqX, freqY, phaseX, phaseY, ampX, ampY);

    // Draw the "sand" trail
    float trailLength = 100.0 + energy * 50.0;
    float minDist = 1000.0;

    for (float i = 0.0; i < 150.0; i += 1.0) {
        if (i >= trailLength) break;

        float t = time * 2.0 - i * 0.02;
        vec2 pos = lissajous(t, freqX, freqY, phaseX, phaseY, ampX, ampY);

        float d = length(uv - pos);
        minDist = min(minDist, d);

        // Sand grains with fading
        float fade = 1.0 - i / trailLength;
        float grain = exp(-d * 80.0) * fade * 0.15;

        // Color shifts along trail
        float hue = i / trailLength * 0.3 + time * 0.02;
        vec3 sandColor = hsv2rgb(vec3(hue + 0.1, 0.4, 0.9));

        color += sandColor * grain;
    }

    // Draw pendulum bob
    float bobDist = length(uv - pendulumPos);
    float bobSize = 0.025 + beat * 0.01;
    float bob = smoothstep(bobSize, bobSize * 0.3, bobDist);
    float bobGlow = exp(-bobDist * 30.0) * 0.6;

    vec3 bobColor = hsv2rgb(vec3(time * 0.05, 0.6, 1.0));
    color += bobColor * (bob + bobGlow);

    // Draw frame/boundary
    float frameSize = 0.42;
    float frameDist = max(abs(uv.x), abs(uv.y)) - frameSize;
    float frame = exp(-abs(frameDist) * 40.0) * 0.2;
    color += vec3(0.3, 0.25, 0.2) * frame;

    // Corner mounting points
    for (float cx = -1.0; cx <= 1.0; cx += 2.0) {
        for (float cy = -1.0; cy <= 1.0; cy += 2.0) {
            vec2 corner = vec2(cx, cy) * frameSize;
            float cornerDist = length(uv - corner);
            float cornerDot = exp(-cornerDist * 40.0) * 0.3;
            color += vec3(0.4, 0.35, 0.3) * cornerDot;
        }
    }

    // Draw strings to frame edges (simplified - just to show suspension)
    vec2 topAttach = vec2(pendulumPos.x * 0.3, frameSize);
    vec2 sideAttach = vec2(sign(pendulumPos.x) * frameSize, pendulumPos.y * 0.3);

    // Line to top
    float stringLen = length(topAttach - pendulumPos);
    for (float s = 0.0; s < 1.0; s += 0.05) {
        vec2 sp = mix(pendulumPos, topAttach, s);
        float sd = length(uv - sp);
        color += vec3(0.3, 0.3, 0.35) * exp(-sd * 100.0) * 0.1;
    }

    // Center glow on beat
    float centerGlow = exp(-length(uv) * 4.0) * beat * 0.3;
    color += vec3(0.4, 0.35, 0.5) * centerGlow;

    // Pattern complexity indicator
    float complexity = sin(freqX / freqY * PI) * 0.5 + 0.5;
    color *= 0.9 + complexity * 0.2;

    // Vignette
    float vig = 1.0 - length(uv) * 0.2;
    color *= smoothstep(0.0, 1.0, vig);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
