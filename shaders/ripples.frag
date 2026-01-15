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
// WAVE INTERFERENCE - Ripples on Water
// Beautiful interference patterns from multiple wave sources
// ============================================================================

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float hash1(float p) {
    return fract(sin(p * 127.1) * 43758.5453);
}

// Smooth value noise
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

// Fractal brownian motion for organic movement
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Smooth circular ripple with realistic physics - no hard cutoffs
float smoothRipple(vec2 uv, vec2 center, float age, float speed, float wavelength, float amplitude) {
    float dist = length(uv - center);

    // Wave travels outward over time
    float wavePos = age * speed;

    // Soft leading edge - wave fades in smoothly ahead of wavefront
    // Uses wide transition zone (2x wavelength) for gradual appearance
    float leadingEdge = smoothstep(wavePos + wavelength * 2.0, wavePos, dist);

    // Soft trailing edge - wave fades out smoothly behind wavefront
    // Longer tail (5x wavelength) for very gradual fade
    float trailingEdge = smoothstep(wavePos - wavelength * 5.0, wavePos - wavelength * 2.0, dist);

    // Combined envelope with extra smoothing
    float envelope = leadingEdge * trailingEdge;
    envelope = envelope * envelope; // Square for even smoother transitions

    // The actual wave oscillation
    float phase = (dist - wavePos) / wavelength * TAU;
    float wave = sin(phase) * amplitude * envelope;

    // Gentler decay over time and distance
    float timeDecay = exp(-age * 0.5);  // Slower time decay
    float distDecay = exp(-dist * 0.3); // Slower distance decay

    return wave * timeDecay * distDecay;
}

// Continuous background waves (wind on water)
float windWaves(vec2 uv, float time, float bass, float mid) {
    float waves = 0.0;

    // Multiple overlapping wave directions
    waves += sin(uv.x * 8.0 + uv.y * 3.0 + time * 2.5) * 0.04;
    waves += sin(uv.x * 5.0 - uv.y * 7.0 + time * 1.8) * 0.03;
    waves += sin(uv.x * 12.0 + uv.y * 4.0 - time * 3.2) * 0.02;

    // Bass adds larger swells
    waves += sin(uv.y * 3.0 + time * 1.5) * bass * 0.08;
    waves += sin(uv.x * 2.5 - time * 1.2) * bass * 0.06;

    // Mid adds medium frequency ripples
    waves += sin(length(uv) * 10.0 - time * 4.0) * mid * 0.04;

    return waves;
}

// ============================================================================
// MAIN
// ============================================================================

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
    // WAVE HEIGHT CALCULATION
    // ========================================================================

    float height = 0.0;

    // Background wind waves - always present, gentle movement
    height += windWaves(uv, time, bass, mid);

    // Central pulsing ripple - breathes with bass
    // Use smoothstep to fade out as age approaches the loop point
    float centralAge = mod(time, 5.0);
    float centralFade = smoothstep(4.5, 4.0, centralAge) * smoothstep(0.0, 0.3, centralAge);
    float centralAmp = (0.15 + bass * 0.25) * centralFade;
    height += smoothRipple(uv, vec2(0.0), centralAge, 0.3 + bass * 0.2, 0.08, centralAmp);

    // Secondary central ripple offset in time - staggered for continuous flow
    float central2Age = mod(time + 2.5, 5.0);
    float central2Fade = smoothstep(4.5, 4.0, central2Age) * smoothstep(0.0, 0.3, central2Age);
    height += smoothRipple(uv, vec2(0.0), central2Age, 0.25, 0.1, (0.15 + bass * 0.25) * 0.7 * central2Fade);

    // Third central ripple for even smoother continuous feel
    float central3Age = mod(time + 1.25, 5.0);
    float central3Fade = smoothstep(4.5, 4.0, central3Age) * smoothstep(0.0, 0.3, central3Age);
    height += smoothRipple(uv, vec2(0.0), central3Age, 0.28, 0.09, (0.15 + bass * 0.25) * 0.5 * central3Fade);

    // Beat-triggered ripples from multiple sources
    // These spawn based on time quantization to create rhythm
    for (float i = 0.0; i < 8.0; i++) {
        // Stagger birth times with longer periods for smoother feel
        float period = 2.0 + hash1(i) * 1.5;
        float birthTime = floor(time / period) * period + hash1(i + 10.0) * 0.5;
        float age = time - birthTime;
        float maxAge = 5.0;

        if (age > 0.0 && age < maxAge) {
            // Position in a ring around center
            float angle = hash1(birthTime + i * 7.3) * TAU;
            float radius = 0.12 + hash1(birthTime * 2.0 + i) * 0.28;
            vec2 pos = vec2(cos(angle), sin(angle)) * radius;

            // Slight position drift
            pos += vec2(fbm(pos * 3.0 + time * 0.1) - 0.5, fbm(pos * 3.0 + 100.0 + time * 0.1) - 0.5) * 0.05;

            float speed = 0.2 + hash1(birthTime * 3.0 + i) * 0.15;
            float wavelength = 0.06 + hash1(birthTime + i * 2.0) * 0.04;
            float amp = (0.1 + energy * 0.15) * (0.7 + hash1(i) * 0.6);

            // Smooth fade in and out over the ripple's lifetime
            float lifeFade = smoothstep(0.0, 0.5, age) * smoothstep(maxAge, maxAge - 1.0, age);
            height += smoothRipple(uv, pos, age, speed, wavelength, amp * lifeFade);
        }
    }

    // Beat burst - smooth expansion triggered by beat
    // Use beat value to control both presence and intensity
    float beatAge = (1.0 - beat) * 0.8; // Slower expansion for smoother look
    float beatAmp = beat * beat * 0.25; // Squared for softer response
    height += smoothRipple(uv, vec2(0.0), beatAge, 0.5, 0.06, beatAmp);

    // Treble creates fine surface texture
    float trebleRipple = noise(uv * 30.0 + time * 3.0) * treble * 0.03;
    trebleRipple += noise(uv * 50.0 - time * 4.0) * treble * 0.02;
    height += trebleRipple;

    // ========================================================================
    // WATER COLORING & LIGHTING
    // ========================================================================

    // Calculate surface normal from height gradient
    vec2 grad = vec2(dFdx(height), dFdy(height)) * 15.0;
    vec3 normal = normalize(vec3(-grad.x, -grad.y, 1.0));

    // Light direction (from above-front)
    vec3 lightDir = normalize(vec3(0.2, 0.3, 1.0));
    vec3 viewDir = vec3(0.0, 0.0, 1.0);
    vec3 halfVec = normalize(lightDir + viewDir);

    // Lighting calculations
    float diffuse = max(dot(normal, lightDir), 0.0);
    float specular = pow(max(dot(normal, halfVec), 0.0), 64.0);

    // Fresnel effect (edge reflection)
    float fresnel = pow(1.0 - max(dot(normal, viewDir), 0.0), 3.0);

    // Base water colors
    vec3 deepColor = vec3(0.01, 0.04, 0.1);
    vec3 surfaceColor = vec3(0.05, 0.15, 0.3);
    vec3 highlightColor = vec3(0.7, 0.85, 1.0);
    vec3 reflectionColor = vec3(0.3, 0.4, 0.6);

    // Tint based on audio
    deepColor += vec3(0.03, 0.01, 0.02) * bass;
    surfaceColor += vec3(0.05, 0.02, 0.08) * mid;
    highlightColor += vec3(0.2, 0.0, 0.3) * beat;

    // Combine colors
    vec3 color = deepColor;

    // Add surface color based on wave height
    color = mix(color, surfaceColor, smoothstep(-0.05, 0.1, height));

    // Diffuse lighting
    color += surfaceColor * diffuse * 0.3;

    // Specular highlights on wave peaks
    color += highlightColor * specular * (0.5 + beat * 0.5);

    // Fresnel reflection
    color = mix(color, reflectionColor, fresnel * 0.4);

    // Caustics - dancing light patterns
    vec2 causticUV = uv * 8.0 + grad * 2.0;
    float caustic = 0.0;
    caustic += pow(abs(sin(causticUV.x + time * 1.5) * sin(causticUV.y * 1.3 + time * 1.2)), 4.0);
    caustic += pow(abs(sin(causticUV.x * 0.7 - time * 1.1) * sin(causticUV.y * 0.9 + time * 0.9)), 4.0);
    caustic *= 0.15 * (1.0 - fresnel);
    color += vec3(0.3, 0.5, 0.6) * caustic;

    // Beat pulse glow from center
    float beatGlow = exp(-length(uv) * (3.0 - beat * 2.0)) * beat * 0.6;
    color += vec3(0.4, 0.2, 0.6) * beatGlow;

    // ========================================================================
    // FLOATING PARTICLES (shimmering light motes on water)
    // ========================================================================

    for (float i = 0.0; i < 12.0; i++) {
        float t = time * 0.2 + i * 1.7;
        vec2 particlePos = vec2(sin(t * 0.5 + i * 0.8) * 0.4, cos(t * 0.4 + i * 1.2) * 0.4);

        float dist = length(uv - particlePos);
        float core = exp(-dist * 100.0);
        float outer = exp(-dist * 30.0);
        float glow = core * 1.5 + outer * 0.6;

        // Simplified shimmering
        float shimmer = sin(time * 5.0 + i * 7.3) * sin(time * 8.0 + i * 3.1);
        shimmer = 0.6 + shimmer * 0.4;
        float sparkle = pow(max(shimmer, 0.0), 4.0);

        glow *= shimmer * (0.6 + energy * 0.5);
        glow += sparkle * core * 2.0;

        vec3 particleColor = mix(vec3(0.7, 0.9, 1.0), vec3(1.0, 0.95, 0.8), hash1(i));
        color += particleColor * glow;
    }

    // ========================================================================
    // FINAL ADJUSTMENTS
    // ========================================================================

    // Vignette
    float vig = 1.0 - length(uv) * 0.35;
    vig = smoothstep(0.0, 1.0, vig);
    color *= vig;

    // Energy boost
    color *= 0.85 + energy * 0.25;

    // Subtle noise to prevent banding
    color += (hash(fragCoord + fract(time)) - 0.5) * 0.015;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
