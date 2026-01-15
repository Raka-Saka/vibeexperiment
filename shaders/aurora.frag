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

// ============================================================================
// AURORA BOREALIS - Northern Lights
// Flowing curtains of light with distinct separation
// Optimized for performance
// ============================================================================

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Simple 2D noise - optimized
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Single aurora curtain - creates a distinct band of light
float auroraBand(vec2 uv, float yCenter, float width, float time, float waveFreq, float waveAmp) {
    // Horizontal wave movement
    float wave = sin(uv.x * waveFreq + time) * waveAmp;
    wave += sin(uv.x * waveFreq * 0.7 - time * 0.8) * waveAmp * 0.5;

    // Distance from the band center
    float bandY = yCenter + wave;
    float dist = abs(uv.y - bandY);

    // Sharp band with soft edges
    float band = smoothstep(width, width * 0.3, dist);

    // Vertical rays within the band
    float rays = sin(uv.x * 30.0 + noise(vec2(uv.x * 5.0, time * 0.5)) * 10.0);
    rays = pow(max(rays, 0.0), 3.0);

    // Combine band with rays
    band *= 0.7 + rays * 0.5;

    // Fade at edges of screen
    band *= smoothstep(0.0, 0.1, uv.y) * smoothstep(1.0, 0.7, uv.y);
    band *= smoothstep(-0.5, 0.0, uv.x) * smoothstep(1.5, 1.0, uv.x);

    return band;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;

    float time = uTime;
    float bass = uBass;
    float mid = uMid;
    float treble = uTreble;
    float energy = uEnergy;
    float beat = uBeat;

    // ========================================================================
    // NIGHT SKY
    // ========================================================================

    // Simple gradient sky
    vec3 skyColor = mix(
        vec3(0.02, 0.01, 0.05),  // Bottom - dark purple
        vec3(0.0, 0.0, 0.02),    // Top - near black
        uv.y
    );

    vec3 color = skyColor;

    // Stars - reduced count for performance
    for (float i = 0.0; i < 30.0; i++) {
        vec2 starPos = vec2(hash(vec2(i, 0.0)), hash(vec2(i, 1.0)));
        float starDist = length(uv - starPos);
        float twinkle = sin(time * 2.0 + i * 7.0) * 0.5 + 0.5;
        float star = exp(-starDist * 150.0) * twinkle * 0.5;
        color += vec3(0.9, 0.95, 1.0) * star;
    }

    // ========================================================================
    // AURORA BANDS - Distinct separated curtains
    // ========================================================================

    // Band 1: Lower green band - responds to bass
    float band1Y = 0.35 + bass * 0.05;
    float band1 = auroraBand(uv, band1Y, 0.08 + bass * 0.03, time * 0.4, 4.0, 0.03);
    vec3 green = vec3(0.2, 0.9, 0.4);
    color += green * band1 * (0.6 + bass * 0.6);

    // Band 2: Middle cyan band - responds to mid
    float band2Y = 0.5 + mid * 0.05;
    float band2 = auroraBand(uv, band2Y, 0.06 + mid * 0.02, time * 0.35 + 1.0, 5.0, 0.025);
    vec3 cyan = vec3(0.2, 0.8, 0.9);
    color += cyan * band2 * (0.5 + mid * 0.6);

    // Band 3: Upper purple band - responds to treble
    float band3Y = 0.65 + treble * 0.04;
    float band3 = auroraBand(uv, band3Y, 0.05 + treble * 0.02, time * 0.45 + 2.0, 6.0, 0.02);
    vec3 purple = vec3(0.6, 0.3, 0.9);
    color += purple * band3 * (0.4 + treble * 0.6);

    // Band 4: Highest pink accent - responds to energy
    float band4Y = 0.75 + energy * 0.03;
    float band4 = auroraBand(uv, band4Y, 0.04, time * 0.5 + 3.0, 7.0, 0.015);
    vec3 pink = vec3(0.9, 0.4, 0.7);
    color += pink * band4 * 0.3 * energy;

    // ========================================================================
    // VERTICAL RAYS - The characteristic aurora "columns"
    // ========================================================================

    // Add distinct vertical ray structure
    float rayX = uv.x + time * 0.05;
    float rays = 0.0;

    // Multiple ray frequencies for organic look
    rays += pow(max(sin(rayX * 20.0), 0.0), 8.0) * 0.3;
    rays += pow(max(sin(rayX * 35.0 + 1.0), 0.0), 10.0) * 0.2;
    rays += pow(max(sin(rayX * 50.0 + 2.0), 0.0), 12.0) * 0.15;

    // Rays only visible where aurora is
    float auroraPresence = band1 + band2 + band3 + band4;
    rays *= auroraPresence;

    // Ray color follows dominant aurora
    vec3 rayColor = green * band1 + cyan * band2 + purple * band3;
    rayColor = normalize(rayColor + 0.001) * 0.8;
    color += rayColor * rays * (0.3 + energy * 0.3);

    // ========================================================================
    // SHIMMER / SPARKLE
    // ========================================================================

    // Quick sparkle effect on aurora
    float sparkle = noise(vec2(uv.x * 50.0 + time * 2.0, uv.y * 30.0));
    sparkle = pow(sparkle, 5.0) * auroraPresence;
    color += vec3(0.8, 0.9, 1.0) * sparkle * 0.3;

    // ========================================================================
    // HORIZON GLOW
    // ========================================================================

    // Subtle glow at horizon where aurora meets land
    float horizonGlow = exp(-uv.y * 8.0) * 0.15;
    color += vec3(0.1, 0.15, 0.1) * horizonGlow * (1.0 + bass * 0.5);

    // Mountain silhouette
    float mountainShape = 0.05 + sin(uv.x * 8.0) * 0.02 + sin(uv.x * 15.0) * 0.01;
    mountainShape += noise(vec2(uv.x * 3.0, 0.0)) * 0.03;
    if (uv.y < mountainShape) {
        color = vec3(0.01, 0.01, 0.02);
    }

    // ========================================================================
    // BEAT EFFECTS
    // ========================================================================

    // Beat causes brief brightening
    color *= 1.0 + beat * 0.4;

    // Beat pulse from horizon
    float beatWave = exp(-(uv.y - beat * 0.3) * 10.0) * beat * 0.3;
    color += vec3(0.3, 0.5, 0.3) * beatWave;

    // ========================================================================
    // FINAL
    // ========================================================================

    // Vignette
    vec2 vigUV = uv - 0.5;
    float vig = 1.0 - dot(vigUV, vigUV) * 0.5;
    color *= vig;

    // Overall energy brightness
    color *= 0.9 + energy * 0.2;

    // Tone mapping
    color = color / (1.0 + color * 0.3);

    // Dither
    color += (hash(fragCoord + fract(time)) - 0.5) * 0.02;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
