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
// STRANGE ATTRACTORS
// Mathematical Foundation: Chaotic systems like Clifford and De Jong attractors
// These create infinitely complex, never-repeating patterns
// ============================================================================

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Clifford Attractor iteration
// x' = sin(a * y) + c * cos(a * x)
// y' = sin(b * x) + d * cos(b * y)
vec2 clifford(vec2 p, float a, float b, float c, float d) {
    return vec2(
        sin(a * p.y) + c * cos(a * p.x),
        sin(b * p.x) + d * cos(b * p.y)
    );
}

// De Jong Attractor
// x' = sin(a * y) - cos(b * x)
// y' = sin(c * x) - cos(d * y)
vec2 dejong(vec2 p, float a, float b, float c, float d) {
    return vec2(
        sin(a * p.y) - cos(b * p.x),
        sin(c * p.x) - cos(d * p.y)
    );
}

// Hash for pseudo-random starting points
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453) * 2.0 - 1.0;
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

    // Dark background with depth
    vec3 bgColor = vec3(0.01, 0.02, 0.04);
    float bgGrad = 1.0 - length(uv) * 0.3;
    bgColor += vec3(0.02, 0.01, 0.03) * bgGrad;

    vec3 color = bgColor;

    // ========================================================================
    // ATTRACTOR PARAMETERS - Audio controlled
    // ========================================================================

    // Clifford attractor parameters controlled by audio
    // These create wildly different patterns based on values
    float a = -1.4 + bass * 0.8 + sin(time * 0.1) * 0.3;
    float b = 1.6 + mid * 0.6 + cos(time * 0.13) * 0.2;
    float c = 1.0 + treble * 0.5 + sin(time * 0.17) * 0.25;
    float d = 0.7 + energy * 0.4 + cos(time * 0.11) * 0.2;

    // De Jong parameters (different pattern)
    float a2 = 1.4 + uBand0 * 0.6;
    float b2 = -2.3 + uBand2 * 0.5;
    float c2 = 2.4 + uBand4 * 0.4;
    float d2 = -2.1 + uBand6 * 0.5;

    // ========================================================================
    // ATTRACTOR DENSITY FIELD
    // Instead of drawing points, we compute how close the attractor passes
    // ========================================================================

    // Scale UV to attractor space
    vec2 attUV = uv * 2.5;

    // Accumulate density from multiple iterations starting from grid points
    float density1 = 0.0;  // Clifford
    float density2 = 0.0;  // De Jong

    // Reduced samples and iterations for mobile performance
    int samples = 4;
    int iterations = 20;

    for (int s = 0; s < 4; s++) {
        if (s >= samples) break;

        // Starting point from a grid with hash offset
        vec2 startGrid = vec2(float(s % 2) - 0.5, float(s / 2) - 0.5) * 1.2;
        vec2 startOffset = hash2(startGrid + vec2(time * 0.1, 0.0)) * 0.5;
        vec2 p1 = startGrid + startOffset;
        vec2 p2 = startGrid - startOffset;

        // Iterate the attractors
        for (int i = 0; i < 20; i++) {
            if (i >= iterations) break;

            // Clifford iteration
            p1 = clifford(p1, a, b, c, d);

            // Check proximity to current pixel
            float dist1 = length(attUV - p1);
            float iterFade = 1.0 - float(i) / float(iterations) * 0.5;
            density1 += exp(-dist1 * 15.0) * 0.2 * iterFade;

            // De Jong iteration
            p2 = dejong(p2, a2, b2, c2, d2);
            float dist2 = length(attUV - p2);
            density2 += exp(-dist2 * 15.0) * 0.18 * iterFade;
        }
    }

    // ========================================================================
    // COLOR THE ATTRACTORS
    // ========================================================================

    // Clifford attractor - cool colors (blue/purple)
    float hue1 = 0.6 + bass * 0.1 + time * 0.02;
    vec3 color1 = hsv2rgb(vec3(hue1, 0.7, 0.9));
    color += color1 * density1 * (0.7 + energy * 0.5);

    // De Jong attractor - warm colors (orange/red)
    float hue2 = 0.05 + treble * 0.1 + time * 0.015;
    vec3 color2 = hsv2rgb(vec3(hue2, 0.8, 0.85));
    color += color2 * density2 * (0.5 + mid * 0.4);

    // ========================================================================
    // ANIMATED PARTICLE TRAILS (optimized)
    // ========================================================================

    // Draw actual particle trails following the attractor
    vec2 trail1 = vec2(0.1, 0.1);
    vec2 trail2 = vec2(-0.1, 0.1);

    // Pre-iterate to get to interesting part of attractor (reduced)
    for (int i = 0; i < 30; i++) {
        trail1 = clifford(trail1, a, b, c, d);
        trail2 = dejong(trail2, a2, b2, c2, d2);
    }

    // Draw visible trail (reduced)
    int trailLength = 30 + int(energy * 20.0);
    for (int i = 0; i < 50; i++) {
        if (i >= trailLength) break;

        trail1 = clifford(trail1, a, b, c, d);
        trail2 = dejong(trail2, a2, b2, c2, d2);

        // Linear fade plus smooth end fade to prevent abrupt cutoff
        float normalizedPos = float(i) / float(trailLength);
        float linearFade = 1.0 - normalizedPos;
        float endFade = 1.0 - smoothstep(0.6, 1.0, normalizedPos);
        float fade = linearFade * endFade;

        // Trail 1 (Clifford)
        float d1 = length(attUV - trail1);
        float t1 = exp(-d1 * 50.0) * fade;
        color += color1 * t1 * 0.5;

        // Trail 2 (De Jong)
        float d2 = length(attUV - trail2);
        float t2 = exp(-d2 * 50.0) * fade;
        color += color2 * t2 * 0.4;
    }

    // ========================================================================
    // BEAT EFFECTS
    // ========================================================================

    // Radial pulse on beat
    float dist = length(uv);
    float beatPulse = sin(dist * 30.0 - time * 5.0) * 0.5 + 0.5;
    beatPulse *= exp(-dist * 2.0) * beat;
    color += vec3(0.4, 0.3, 0.5) * beatPulse * 0.4;

    // Center glow
    float centerGlow = exp(-dist * 3.0) * (0.2 + beat * 0.3);
    color += vec3(0.3, 0.2, 0.4) * centerGlow;

    // ========================================================================
    // ROTATION AND PERSPECTIVE
    // ========================================================================

    // Subtle 3D rotation effect
    float rotAngle = time * 0.05;
    vec2 rotUV = vec2(
        uv.x * cos(rotAngle) - uv.y * sin(rotAngle) * 0.3,
        uv.y * cos(rotAngle) + uv.x * sin(rotAngle) * 0.3
    );

    // Depth fog effect
    float depthFog = 1.0 - length(rotUV - uv) * 2.0;
    color *= 0.8 + depthFog * 0.2;

    // ========================================================================
    // FINAL EFFECTS
    // ========================================================================

    // Color cycling speed from beat
    float colorShift = beat * 0.1;
    color.rgb = color.rgb * (1.0 - colorShift) + color.gbr * colorShift;

    // Energy brightness
    color *= 0.85 + energy * 0.25;

    // Vignette
    float vig = 1.0 - dist * 0.35;
    color *= smoothstep(0.0, 1.0, vig);

    // Clamp and output
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
