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
// CELESTIAL HALOS - Ethereal Light Rings
// Soft, luminous halos floating in space - dreamy and transcendent
// Like light through morning mist or halos around stars
// ============================================================================

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth noise with quintic interpolation
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Soft ethereal halo - very gentle falloff
float softHalo(vec2 uv, float radius, float softness) {
    float dist = length(uv);
    float inner = smoothstep(radius - softness, radius, dist);
    float outer = smoothstep(radius + softness, radius, dist);
    return inner * outer;
}

// Glowing ring with organic wobble
float etherealRing(vec2 uv, float radius, float thickness, float wobbleAmt, float time) {
    float angle = atan(uv.y, uv.x);
    float dist = length(uv);

    // Organic wobble using noise
    float wobble = noise(vec2(angle * 2.0 + time * 0.3, time * 0.2)) * wobbleAmt;
    wobble += sin(angle * 3.0 + time * 0.5) * wobbleAmt * 0.5;

    float adjustedRadius = radius + wobble;

    // Very soft ring falloff
    float ring = exp(-pow(abs(dist - adjustedRadius) / thickness, 2.0));

    return ring;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = (fragCoord - uSize * 0.5) / min(uSize.x, uSize.y);

    float time = uTime;
    float bass = uBass;
    float mid = uMid;
    float treble = uTreble;
    float energy = uEnergy;
    float beat = uBeat;

    // ========================================================================
    // DEEP SPACE BACKGROUND
    // ========================================================================

    // Gradient from deep blue to purple-black
    vec3 bgDeep = vec3(0.01, 0.01, 0.03);
    vec3 bgMid = vec3(0.02, 0.01, 0.04);
    vec3 color = mix(bgDeep, bgMid, length(uv) * 0.5);

    // Subtle nebula texture
    float nebula = noise(uv * 3.0 + time * 0.02);
    nebula *= noise(uv * 5.0 - time * 0.015);
    color += vec3(0.02, 0.01, 0.03) * nebula;

    // ========================================================================
    // DISTANT STARS
    // ========================================================================

    for (float i = 0.0; i < 20.0; i++) {
        vec2 starPos = vec2(hash(vec2(i, 0.0)) - 0.5, hash(vec2(i, 1.0)) - 0.5) * 1.2;
        float starDist = length(uv - starPos);
        float twinkle = sin(time * (1.5 + hash(vec2(i, 2.0))) + i * 5.0) * 0.4 + 0.6;
        float star = exp(-starDist * 80.0) * twinkle * 0.5;
        vec3 starColor = mix(vec3(0.8, 0.85, 1.0), vec3(1.0, 0.95, 0.85), hash(vec2(i, 3.0)));
        color += starColor * star;
    }

    // ========================================================================
    // CENTRAL LIGHT SOURCE - Warm glowing heart
    // ========================================================================

    float centerDist = length(uv);

    // Core glow
    float coreGlow = exp(-centerDist * 6.0);
    vec3 coreColor = hsv2rgb(vec3(0.1 + bass * 0.05, 0.3, 1.0));
    coreColor = mix(coreColor, vec3(1.0, 0.98, 0.95), beat * 0.5);
    color += coreColor * coreGlow * (0.4 + bass * 0.4);

    // Inner bright core
    float innerCore = exp(-centerDist * 15.0);
    color += vec3(1.0, 0.98, 0.95) * innerCore * 0.5;

    // ========================================================================
    // ETHEREAL HALOS - Soft luminous rings
    // ========================================================================

    // Halo 1: Inner bass halo - warm gold
    float halo1 = etherealRing(uv, 0.12 + bass * 0.03, 0.04 + bass * 0.02, 0.02 + bass * 0.01, time);
    vec3 halo1Color = hsv2rgb(vec3(0.1, 0.4, 0.9));
    color += halo1Color * halo1 * (0.4 + bass * 0.5);

    // Halo 2: Mid halo - soft rose
    float halo2 = etherealRing(uv, 0.2 + mid * 0.02, 0.05 + mid * 0.02, 0.015, time * 0.9 + 1.0);
    vec3 halo2Color = hsv2rgb(vec3(0.95, 0.35, 0.85));
    color += halo2Color * halo2 * (0.35 + mid * 0.45);

    // Halo 3: Outer halo - ethereal cyan
    float halo3 = etherealRing(uv, 0.3 + treble * 0.02, 0.06, 0.012, time * 0.8 + 2.0);
    vec3 halo3Color = hsv2rgb(vec3(0.55, 0.3, 0.8));
    color += halo3Color * halo3 * (0.3 + treble * 0.4);

    // Halo 4: Distant halo - soft lavender
    float halo4 = etherealRing(uv, 0.42 + energy * 0.02, 0.07, 0.01, time * 0.7 + 3.0);
    vec3 halo4Color = hsv2rgb(vec3(0.75, 0.25, 0.75));
    color += halo4Color * halo4 * (0.25 + energy * 0.35);

    // Halo 5: Outermost whisper
    float halo5 = etherealRing(uv, 0.55, 0.08, 0.008, time * 0.6 + 4.0);
    vec3 halo5Color = hsv2rgb(vec3(0.6, 0.2, 0.7));
    color += halo5Color * halo5 * 0.2 * energy;

    // ========================================================================
    // FLOATING LIGHT MOTES
    // ========================================================================

    for (float i = 0.0; i < 12.0; i++) {
        float seed = i * 7.3;

        // Gentle orbital motion
        float orbitRadius = 0.15 + hash(vec2(seed, 0.0)) * 0.35;
        float orbitSpeed = 0.2 + hash(vec2(seed, 1.0)) * 0.3;
        float angle = time * orbitSpeed + seed;

        // Add gentle vertical drift
        float vertDrift = sin(time * 0.3 + seed) * 0.05;

        vec2 motePos = vec2(cos(angle), sin(angle) + vertDrift) * orbitRadius;
        float moteDist = length(uv - motePos);

        // Soft glowing mote
        float mote = exp(-moteDist * 30.0);

        // Gentle pulsing
        float pulse = sin(time * 2.0 + seed * 3.0) * 0.3 + 0.7;
        mote *= pulse;

        // Color varies with position
        vec3 moteColor = hsv2rgb(vec3(hash(vec2(seed, 2.0)) * 0.3 + 0.5, 0.3, 1.0));
        color += moteColor * mote * (0.2 + energy * 0.2);
    }

    // ========================================================================
    // BEAT PULSE - Soft expanding ring
    // ========================================================================

    if (beat > 0.1) {
        float pulseRadius = beat * 0.5;
        float pulseDist = abs(centerDist - pulseRadius);
        float pulse = exp(-pulseDist * 10.0) * beat;
        color += vec3(1.0, 0.95, 0.98) * pulse * 0.4;

        // Inner beat glow
        float beatGlow = exp(-centerDist * 4.0) * beat;
        color += vec3(1.0, 0.9, 0.95) * beatGlow * 0.3;
    }

    // ========================================================================
    // LIGHT RAYS - Subtle radial beams
    // ========================================================================

    float rayAngle = atan(uv.y, uv.x);
    float rays = 0.0;

    // Multiple soft ray frequencies
    rays += pow(max(sin(rayAngle * 6.0 + time * 0.2), 0.0), 4.0) * 0.15;
    rays += pow(max(sin(rayAngle * 8.0 - time * 0.15), 0.0), 5.0) * 0.1;

    // Rays fade with distance
    rays *= exp(-centerDist * 2.0);
    rays *= energy;

    color += vec3(0.9, 0.85, 1.0) * rays;

    // ========================================================================
    // ATMOSPHERIC EFFECTS
    // ========================================================================

    // Soft overall bloom
    vec3 bloom = max(color - 0.4, 0.0) * 0.3;
    color += bloom;

    // Gentle vignette
    float vig = 1.0 - centerDist * 0.3;
    vig = smoothstep(0.0, 1.0, vig);
    color *= vig;

    // Energy brightness
    color *= 0.85 + energy * 0.25;

    // Soft tone mapping
    color = color / (1.0 + color * 0.25);

    // Dither
    color += (hash(fragCoord + fract(time)) - 0.5) * 0.015;

    fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
