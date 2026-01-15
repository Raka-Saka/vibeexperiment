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
// HARMONOGRAPH - Dreamy Pendulum Art
// Inspired by mechanical drawing machines that create ethereal patterns
// Artistic, flowing, and lyrical
// ============================================================================

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Soft noise for organic movement
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

// HSV to RGB for smooth color transitions
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Harmonograph point - two pendulums combined
vec2 harmonograph(float t, float f1, float f2, float f3, float f4,
                  float p1, float p2, float d1, float d2, float amp) {
    // Two pendulums with damping
    float decay1 = exp(-d1 * t);
    float decay2 = exp(-d2 * t);

    float x = sin(t * f1 + p1) * decay1 + sin(t * f3 + p1 * 0.5) * decay2 * 0.5;
    float y = sin(t * f2 + p2) * decay1 + sin(t * f4 + p2 * 0.5) * decay2 * 0.5;

    return vec2(x, y) * amp;
}

// Soft glow function
float softGlow(float dist, float radius, float softness) {
    return exp(-dist * dist / (radius * softness));
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

    // ========================================================================
    // BACKGROUND - Soft gradient with subtle texture
    // ========================================================================

    // Deep space gradient
    vec3 bgTop = vec3(0.02, 0.01, 0.05);
    vec3 bgBot = vec3(0.04, 0.02, 0.06);
    vec3 color = mix(bgBot, bgTop, uv.y * 0.5 + 0.5);

    // Subtle organic texture
    float bgNoise = noise(uv * 3.0 + time * 0.05);
    color += vec3(0.02, 0.01, 0.03) * bgNoise;

    // ========================================================================
    // HARMONOGRAPH PARAMETERS - Audio drives the pattern shape
    // ========================================================================

    // Frequency ratios create different patterns
    // Near-integer ratios create closed curves, irrational = spirals
    float baseFreq = 2.0 + bass * 1.5;

    // Primary pendulum frequencies
    float f1 = baseFreq;
    float f2 = baseFreq * (1.0 + mid * 0.5);  // Slight detune for evolution

    // Secondary pendulum (creates complexity)
    float f3 = f1 * 2.0 + treble;
    float f4 = f2 * 2.0 - treble * 0.5;

    // Phase - controls rotation and symmetry
    float phase1 = time * 0.2 + beat * 0.5;
    float phase2 = time * 0.15 + PI * 0.5;

    // Damping - how quickly oscillations fade
    float damp1 = 0.02 + energy * 0.03;
    float damp2 = 0.03 + bass * 0.02;

    // Amplitude
    float amp = 0.35 + energy * 0.08;

    // ========================================================================
    // DRAW THE CURVE - Sample points along the harmonograph
    // ========================================================================

    float minDist = 1000.0;
    vec3 closestColor = vec3(0.0);
    float closestT = 0.0;

    // Sample the curve at multiple points (optimized count)
    for (float i = 0.0; i < 60.0; i++) {
        // Parameter along the curve
        float t = i * 0.15 + time * 0.3;

        // Get point on harmonograph
        vec2 p = harmonograph(t, f1, f2, f3, f4, phase1, phase2, damp1, damp2, amp);

        // Distance from current pixel to this point
        float dist = length(uv - p);

        if (dist < minDist) {
            minDist = dist;
            closestT = t;
        }
    }

    // ========================================================================
    // CURVE RENDERING - Soft glowing line
    // ========================================================================

    // Main curve glow
    float curveGlow = softGlow(minDist, 0.015 + bass * 0.01, 1.0);

    // Color varies along the curve (hue shift)
    float hue = fract(closestT * 0.02 + time * 0.05);
    float sat = 0.6 + energy * 0.3;
    float val = 0.9;
    vec3 curveColor = hsv2rgb(vec3(hue, sat, val));

    // Add the main curve
    color += curveColor * curveGlow * (0.8 + energy * 0.4);

    // Outer soft glow (aura)
    float auraGlow = softGlow(minDist, 0.08, 2.0) * 0.3;
    color += curveColor * auraGlow * energy;

    // ========================================================================
    // SECONDARY CURVES - Ethereal echoes
    // ========================================================================

    // Echo 1 - Slightly phase-shifted
    float minDist2 = 1000.0;
    for (float i = 0.0; i < 40.0; i++) {
        float t = i * 0.18 + time * 0.25 + PI;
        vec2 p = harmonograph(t, f1 * 0.8, f2 * 1.2, f3, f4,
                              phase1 + PI * 0.3, phase2 - PI * 0.2,
                              damp1 * 1.5, damp2 * 1.5, amp * 0.7);
        float dist = length(uv - p);
        minDist2 = min(minDist2, dist);
    }

    float echo1Glow = softGlow(minDist2, 0.012, 1.2);
    vec3 echo1Color = hsv2rgb(vec3(fract(hue + 0.3), sat * 0.8, val * 0.7));
    color += echo1Color * echo1Glow * (0.4 + mid * 0.4);

    // Echo 2 - Treble-driven, more intricate
    float minDist3 = 1000.0;
    for (float i = 0.0; i < 30.0; i++) {
        float t = i * 0.2 + time * 0.35;
        vec2 p = harmonograph(t, f1 * 1.5, f2 * 1.5, f3 * 0.7, f4 * 0.7,
                              phase1 * 2.0, phase2 * 2.0,
                              damp1 * 0.8, damp2 * 0.8, amp * 0.5);
        float dist = length(uv - p);
        minDist3 = min(minDist3, dist);
    }

    float echo2Glow = softGlow(minDist3, 0.01, 1.0);
    vec3 echo2Color = hsv2rgb(vec3(fract(hue + 0.6), sat * 0.7, val * 0.6));
    color += echo2Color * echo2Glow * (0.3 + treble * 0.5);

    // ========================================================================
    // FLOATING PARTICLES - Dust motes in the light
    // ========================================================================

    for (float i = 0.0; i < 15.0; i++) {
        float seed = i * 7.3;

        // Particle drifts slowly
        float pt = time * 0.1 + seed;
        vec2 particlePos = vec2(
            sin(pt * 0.3 + seed) * 0.4,
            cos(pt * 0.25 + seed * 1.3) * 0.4
        );

        float dist = length(uv - particlePos);

        // Twinkle effect
        float twinkle = sin(time * 3.0 + seed * 5.0) * 0.5 + 0.5;
        twinkle = pow(twinkle, 2.0);

        float particleGlow = exp(-dist * 50.0) * twinkle;

        // Particle color matches curve
        vec3 particleColor = hsv2rgb(vec3(fract(seed * 0.1 + time * 0.02), 0.4, 1.0));
        color += particleColor * particleGlow * (0.3 + energy * 0.3);
    }

    // ========================================================================
    // CENTER BLOOM - Heart of the pattern
    // ========================================================================

    float centerDist = length(uv);
    float centerBloom = exp(-centerDist * 4.0) * (0.2 + beat * 0.4);
    vec3 bloomColor = hsv2rgb(vec3(fract(time * 0.1), 0.5, 1.0));
    color += bloomColor * centerBloom;

    // Beat pulse ring
    if (beat > 0.1) {
        float ringRadius = beat * 0.5;
        float ringDist = abs(centerDist - ringRadius);
        float ring = exp(-ringDist * 30.0) * beat;
        color += vec3(1.0, 0.9, 0.95) * ring * 0.5;
    }

    // ========================================================================
    // ATMOSPHERIC EFFECTS
    // ========================================================================

    // Soft radial gradient overlay
    float radialFade = 1.0 - centerDist * 0.3;
    radialFade = smoothstep(0.0, 1.0, radialFade);

    // Vignette
    float vig = 1.0 - length(uv) * 0.35;
    vig = smoothstep(0.0, 1.0, vig);
    color *= vig;

    // Overall brightness
    color *= 0.9 + energy * 0.2;

    // Soft bloom on bright areas
    vec3 bloom = max(color - 0.7, 0.0) * 0.3;
    color += bloom;

    // Tone mapping
    color = color / (1.0 + color * 0.2);

    // Dither
    color += (hash(fragCoord + fract(time)) - 0.5) * 0.015;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
