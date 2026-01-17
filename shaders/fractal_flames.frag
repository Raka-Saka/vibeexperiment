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

// ============================================================================
// FRACTAL FLAMES
// Mathematical Foundation: Iterated Function Systems (IFS) with nonlinear variations
// Creates ethereal, flame-like fractal patterns with infinite detail
// ============================================================================

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Hash function
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

// ============================================================================
// FLAME VARIATIONS (nonlinear transforms)
// ============================================================================

// V0: Linear
vec2 vLinear(vec2 p) {
    return p;
}

// V1: Sinusoidal
vec2 vSinusoidal(vec2 p) {
    return vec2(sin(p.x), sin(p.y));
}

// V2: Spherical
vec2 vSpherical(vec2 p) {
    float r2 = dot(p, p) + 0.0001;
    return p / r2;
}

// V3: Swirl
vec2 vSwirl(vec2 p) {
    float r2 = dot(p, p);
    float c = cos(r2);
    float s = sin(r2);
    return vec2(p.x * s - p.y * c, p.x * c + p.y * s);
}

// V4: Horseshoe
vec2 vHorseshoe(vec2 p) {
    float r = length(p) + 0.0001;
    return vec2((p.x - p.y) * (p.x + p.y), 2.0 * p.x * p.y) / r;
}

// V5: Polar
vec2 vPolar(vec2 p) {
    float r = length(p);
    float theta = atan(p.y, p.x);
    return vec2(theta / PI, r - 1.0);
}

// V6: Handkerchief
vec2 vHandkerchief(vec2 p) {
    float r = length(p);
    float theta = atan(p.y, p.x);
    return r * vec2(sin(theta + r), cos(theta - r));
}

// V7: Heart
vec2 vHeart(vec2 p) {
    float r = length(p);
    float theta = atan(p.y, p.x);
    return r * vec2(sin(theta * r), -cos(theta * r));
}

// V8: Disc
vec2 vDisc(vec2 p) {
    float r = length(p);
    float theta = atan(p.y, p.x);
    return theta / PI * vec2(sin(PI * r), cos(PI * r));
}

// V9: Spiral
vec2 vSpiral(vec2 p) {
    float r = length(p) + 0.0001;
    float theta = atan(p.y, p.x);
    return vec2(cos(theta) + sin(r), sin(theta) - cos(r)) / r;
}

// Apply weighted combination of variations
vec2 applyVariations(vec2 p, float w0, float w1, float w2, float w3, float w4) {
    vec2 result = vec2(0.0);
    result += w0 * vSinusoidal(p);
    result += w1 * vSpherical(p);
    result += w2 * vSwirl(p);
    result += w3 * vHeart(p);
    result += w4 * vSpiral(p);
    return result;
}

// Affine transform
vec2 affine(vec2 p, float a, float b, float c, float d, float e, float f) {
    return vec2(a * p.x + b * p.y + c, d * p.x + e * p.y + f);
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

    // Deep black background
    vec3 bgColor = vec3(0.0, 0.0, 0.02);
    vec3 color = bgColor;

    // ========================================================================
    // FLAME PARAMETERS - Audio controlled
    // ========================================================================

    // Variation weights from audio bands
    float w0 = 0.3 + uBand0 * 0.5;  // Sinusoidal
    float w1 = 0.2 + uBand2 * 0.4;  // Spherical
    float w2 = 0.3 + uBand4 * 0.5;  // Swirl
    float w3 = 0.1 + uBand6 * 0.3;  // Heart
    float w4 = 0.2 + bass * 0.4;    // Spiral

    // Normalize weights
    float wSum = w0 + w1 + w2 + w3 + w4;
    w0 /= wSum; w1 /= wSum; w2 /= wSum; w3 /= wSum; w4 /= wSum;

    // Affine transform parameters - audio controlled
    float rotAngle = time * 0.2 + bass * 0.5;
    float scale = 0.7 + mid * 0.2;

    // ========================================================================
    // DENSITY ESTIMATION
    // Compute flame density at each pixel using reverse iteration
    // ========================================================================

    float density = 0.0;
    float colorIndex = 0.0;

    // Scale UV to flame space
    vec2 flameUV = uv * 2.5;

    // Further reduced for smooth mobile performance
    int numSamples = 3;
    int iterations = 10;

    for (int s = 0; s < 3; s++) {
        if (s >= numSamples) break;

        // Random starting point
        vec2 p = hash2(vec2(float(s) * 0.1, time * 0.01)) * 2.0 - 1.0;

        // Iterate the IFS
        for (int i = 0; i < 10; i++) {
            if (i >= iterations) break;

            // Choose which transform to apply (simulated random selection)
            float selector = hash(p + vec2(float(i), float(s)));

            // Apply affine transform
            float a = cos(rotAngle) * scale;
            float b = -sin(rotAngle) * scale;
            float d = sin(rotAngle) * scale;
            float e = cos(rotAngle) * scale;

            vec2 offset = vec2(0.0);
            if (selector < 0.33) {
                offset = vec2(0.3 + bass * 0.2, 0.0);
            } else if (selector < 0.66) {
                offset = vec2(-0.3 - mid * 0.2, 0.1);
            } else {
                offset = vec2(0.0, -0.3 - treble * 0.2);
            }

            p = affine(p, a, b, offset.x, d, e, offset.y);

            // Apply variations
            p = applyVariations(p, w0, w1, w2, w3, w4);

            // Skip first few iterations (let it settle)
            if (i < 5) continue;

            // Check proximity to current pixel
            float dist = length(flameUV - p);
            float iterFade = 1.0 - float(i - 5) / float(iterations - 5) * 0.5;

            // Accumulate density
            float contrib = exp(-dist * 10.0) * iterFade;
            density += contrib;

            // Color index for palette lookup
            colorIndex += contrib * (float(i) / float(iterations));
        }
    }

    // Normalize density
    density = density / float(numSamples);

    // ========================================================================
    // FORWARD ITERATION FOR TRAILS (optimized)
    // ========================================================================

    vec2 trail = vec2(0.1, 0.0);
    float trailDensity = 0.0;

    // Pre-compute rotation values once
    float cosR = cos(rotAngle) * scale;
    float sinR = sin(rotAngle) * scale;

    // Pre-iterate (minimal)
    for (int i = 0; i < 12; i++) {
        float sel = hash(trail + vec2(float(i), 0.0));
        vec2 off = sel < 0.5 ? vec2(0.3, 0.0) : vec2(-0.3, 0.1);

        trail = affine(trail, cosR, -sinR, off.x, sinR, cosR, off.y);
        trail = applyVariations(trail, w0, w1, w2, w3, w4);
    }

    // Draw visible trail (minimal)
    for (int i = 0; i < 25; i++) {
        float sel = hash(trail + vec2(float(i + 20), 0.0));
        vec2 off = sel < 0.5 ? vec2(0.3 + bass * 0.2, 0.0) : vec2(-0.3 - mid * 0.2, 0.1);

        trail = affine(trail, cosR, -sinR, off.x, sinR, cosR, off.y);
        trail = applyVariations(trail, w0, w1, w2, w3, w4);

        float dist = length(flameUV - trail);
        float fade = 1.0 - float(i) / 25.0;
        trailDensity += exp(-dist * 20.0) * fade * 0.4;
    }

    // ========================================================================
    // COLORING
    // ========================================================================

    // Fire palette - black -> red -> orange -> yellow -> white
    vec3 fireColor;
    float t = clamp(density * 2.0, 0.0, 1.0);

    if (t < 0.25) {
        fireColor = mix(vec3(0.0), vec3(0.5, 0.0, 0.0), t * 4.0);
    } else if (t < 0.5) {
        fireColor = mix(vec3(0.5, 0.0, 0.0), vec3(1.0, 0.3, 0.0), (t - 0.25) * 4.0);
    } else if (t < 0.75) {
        fireColor = mix(vec3(1.0, 0.3, 0.0), vec3(1.0, 0.8, 0.2), (t - 0.5) * 4.0);
    } else {
        fireColor = mix(vec3(1.0, 0.8, 0.2), vec3(1.0, 1.0, 0.9), (t - 0.75) * 4.0);
    }

    // Hue shift based on audio
    float hueShift = (bass - treble) * 0.2;
    vec3 hsvFire = vec3(
        0.05 + hueShift + t * 0.1,  // Hue: red -> yellow
        1.0 - t * 0.3,              // Saturation decreases at hot spots
        t                           // Value = density
    );

    vec3 flameColor = hsv2rgb(hsvFire);

    // Blend fire colors
    color += fireColor * density * 2.0;
    color += flameColor * density * 0.5;

    // Trail color (cooler, ethereal)
    vec3 trailColor = hsv2rgb(vec3(0.7 + time * 0.01, 0.6, 0.8));
    color += trailColor * trailDensity;

    // ========================================================================
    // BEAT EFFECTS
    // ========================================================================

    // Intensity pulse on beat
    color *= 1.0 + beat * 0.4;

    // Central glow
    float dist = length(uv);
    float centerGlow = exp(-dist * 3.0) * (0.2 + beat * 0.3);
    color += vec3(0.3, 0.1, 0.0) * centerGlow;

    // ========================================================================
    // FINAL EFFECTS
    // ========================================================================

    // Gamma for flame-like look
    color = pow(color, vec3(0.8));

    // Energy modulation
    color *= 0.8 + energy * 0.4;

    // Subtle vignette
    float vig = 1.0 - dist * 0.2;
    color *= smoothstep(0.0, 1.0, vig);

    // Clamp and output
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
