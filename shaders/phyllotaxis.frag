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

// Golden angle in radians (137.5 degrees)
const float GOLDEN_ANGLE = 2.39996322972865332;

// ============================================================================
// PHYLLOTAXIS (SUNFLOWER SPIRALS)
// Mathematical Foundation: Golden angle arrangement
// r = c * sqrt(n)
// theta = n * phi (phi = golden angle = 137.5 degrees)
// ============================================================================

// Hash for variation
float hash(float n) {
    return fract(sin(n * 127.1) * 43758.5453);
}

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Soft circle SDF
float circle(vec2 p, float r) {
    return length(p) - r;
}

// Petal/seed shape
float petalShape(vec2 p, float size) {
    // Elongated circle (ellipse)
    vec2 scaled = p * vec2(1.0, 1.5);
    return length(scaled) - size;
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

    // Background - dark with warm undertone
    vec3 bgColor = vec3(0.03, 0.02, 0.04);

    // Subtle radial gradient
    float bgGrad = 1.0 - length(uv) * 0.5;
    bgColor += vec3(0.02, 0.01, 0.02) * bgGrad;

    vec3 color = bgColor;

    // ========================================================================
    // PHYLLOTAXIS PARAMETERS
    // ========================================================================

    // Number of particles grows with energy (reduced for mobile)
    float maxParticles = 80.0 + energy * 70.0;

    // Spiral tightness from bass
    float spiralTightness = 0.08 + bass * 0.04;

    // Global rotation
    float globalRotation = time * 0.1 + beat * 0.2;

    // Particle size from beat and energy
    float baseSize = 0.025 + beat * 0.015;

    // ========================================================================
    // RENDER PHYLLOTAXIS PATTERN
    // ========================================================================

    float totalIntensity = 0.0;
    vec3 totalColor = vec3(0.0);

    // Rotate UV for global rotation effect
    float cosR = cos(globalRotation);
    float sinR = sin(globalRotation);
    mat2 rotMat = mat2(cosR, -sinR, sinR, cosR);

    vec2 rotUV = rotMat * uv;

    // Iterate through particles (reduced upper bound for mobile)
    for (float n = 1.0; n < 150.0; n += 1.0) {
        if (n > maxParticles) break;

        // Golden angle arrangement
        float theta = n * GOLDEN_ANGLE;
        float r = spiralTightness * sqrt(n);

        // Particle position
        vec2 particlePos = r * vec2(cos(theta), sin(theta));

        // Audio-reactive displacement
        float bandIdx = mod(n, 8.0);
        float bandValue = 0.0;
        if (bandIdx < 1.0) bandValue = uBand0;
        else if (bandIdx < 2.0) bandValue = uBand1;
        else if (bandIdx < 3.0) bandValue = uBand2;
        else if (bandIdx < 4.0) bandValue = uBand3;
        else if (bandIdx < 5.0) bandValue = uBand4;
        else if (bandIdx < 6.0) bandValue = uBand5;
        else if (bandIdx < 7.0) bandValue = uBand6;
        else bandValue = uBand7;

        // Radial breathing based on audio
        float breathe = 1.0 + bandValue * 0.3;
        particlePos *= breathe;

        // Add subtle wave motion
        float wavePhase = n * 0.1 + time * 2.0;
        particlePos += vec2(sin(wavePhase), cos(wavePhase * 1.3)) * 0.01 * treble;

        // Distance from current pixel to particle
        vec2 delta = rotUV - particlePos;

        // Rotate particle for petal effect
        float particleAngle = theta + time * 0.5;
        float cosP = cos(particleAngle);
        float sinP = sin(particleAngle);
        vec2 rotDelta = mat2(cosP, -sinP, sinP, cosP) * delta;

        // Particle size varies with distance from center and audio
        float size = baseSize * (0.5 + 0.5 * (1.0 - r * 0.8));
        size *= (0.7 + bandValue * 0.5);

        // Distance to particle shape
        float d = petalShape(rotDelta, size);

        // Soft particle rendering
        float particleIntensity = smoothstep(size * 0.5, -size * 0.3, d);

        // Glow around particle
        float glow = exp(-max(d, 0.0) * 40.0) * 0.5;

        // Color based on position in spiral
        float hue = n / maxParticles * 0.8 + time * 0.03;
        // Shift hue based on frequency content
        hue += (bass * 0.1 - treble * 0.1);

        float sat = 0.6 + mid * 0.3;
        float val = 0.5 + bandValue * 0.5;

        vec3 particleColor = hsv2rgb(vec3(hue, sat, val));

        // Beat pulse on particles
        float pulse = 1.0 + beat * 0.5 * sin(n * 0.5 + time * 5.0);
        particleColor *= pulse;

        // Accumulate
        totalIntensity += particleIntensity + glow;
        totalColor += particleColor * (particleIntensity + glow * 0.7);
    }

    // Normalize and apply accumulated color
    if (totalIntensity > 0.001) {
        color += totalColor / max(totalIntensity, 1.0) * min(totalIntensity, 2.0);
    }

    // ========================================================================
    // GOLDEN SPIRAL OVERLAY
    // ========================================================================

    // Draw subtle golden spiral guide lines (reduced for mobile)
    float spiralDist = 1000.0;
    for (float arm = 0.0; arm < 4.0; arm += 1.0) {
        float armOffset = arm * TAU / 4.0;

        for (float t = 0.0; t < 25.0; t += 1.0) {
            float theta = t * 0.3 + armOffset;
            float r = spiralTightness * sqrt(t * 5.0);

            vec2 spiralPoint = r * vec2(cos(theta), sin(theta));
            spiralDist = min(spiralDist, length(rotUV - spiralPoint));
        }
    }

    // Subtle spiral guides
    float spiralLine = exp(-spiralDist * 80.0) * 0.1 * energy;
    color += vec3(0.4, 0.3, 0.2) * spiralLine;

    // ========================================================================
    // CENTER EFFECTS
    // ========================================================================

    // Central glow
    float centerDist = length(uv);
    float centerGlow = exp(-centerDist * 4.0) * (0.3 + beat * 0.4);
    color += vec3(0.4, 0.3, 0.2) * centerGlow;

    // Pulsing ring on beat
    float ringRadius = 0.1 + beat * 0.3;
    float ring = abs(centerDist - ringRadius);
    float ringIntensity = exp(-ring * 30.0) * beat;
    color += vec3(0.6, 0.4, 0.2) * ringIntensity;

    // ========================================================================
    // FINISHING EFFECTS
    // ========================================================================

    // Overall energy brightness
    color *= 0.9 + energy * 0.2;

    // Warm color grading
    color = pow(color, vec3(0.95, 1.0, 1.05));

    // Vignette
    float vig = 1.0 - centerDist * 0.3;
    color *= smoothstep(0.0, 1.0, vig);

    // Clamp and output
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
