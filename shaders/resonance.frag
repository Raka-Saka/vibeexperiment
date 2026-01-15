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
// HASH & NOISE
// ============================================================================

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
    float n = sin(dot(p, vec2(127.1, 311.7)));
    return fract(vec2(n, n * 1.234) * 43758.5453);
}

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

// ============================================================================
// CHLADNI PATTERN
// ============================================================================

float chladni(vec2 p, float n, float m) {
    return cos(n * PI * p.x) * cos(m * PI * p.y)
         - cos(m * PI * p.x) * cos(n * PI * p.y);
}

float chladniBlend(vec2 p, float n, float m) {
    float n_low = floor(n);
    float n_high = n_low + 1.0;
    float n_frac = fract(n);
    float m_low = floor(m);
    float m_high = m_low + 1.0;
    float m_frac = fract(m);

    float c00 = chladni(p, n_low, m_low);
    float c10 = chladni(p, n_high, m_low);
    float c01 = chladni(p, n_low, m_high);
    float c11 = chladni(p, n_high, m_high);

    return mix(mix(c00, c10, n_frac), mix(c01, c11, n_frac), m_frac);
}

// Spatial warp to break up repetitive symmetry
vec2 warpSpace(vec2 p, float time, float energy, float bass) {
    // Gentle organic distortion
    float warpStrength = 0.08 + energy * 0.15 + bass * 0.1;
    vec2 warp;
    warp.x = noise(p * 2.0 + time * 0.1) - 0.5;
    warp.y = noise(p * 2.0 + vec2(5.0, 3.0) + time * 0.08) - 0.5;
    return p + warp * warpStrength;
}

// ============================================================================
// MODE FUNCTIONS - More dramatic audio response
// Different n,m combinations create very different patterns
// ============================================================================

vec2 getBassMode(float subBass, float lowBass, float highBass, float time) {
    // Bass: modes 1-5, asymmetric n/m for more interesting patterns
    float n = 1.0 + subBass * 2.0 + lowBass * 1.5;
    float m = 2.0 + highBass * 3.0 + lowBass * 1.0;
    n += sin(time * 0.08) * 0.5;
    m += cos(time * 0.11) * 0.6;
    return vec2(n, m);
}

vec2 getMidMode(float lowMid, float mid, float highMid, float time) {
    // Mid: modes 3-8, more complex patterns
    float n = 3.0 + lowMid * 2.0 + mid * 2.5;
    float m = 4.0 + highMid * 3.0 + mid * 1.5;
    n += sin(time * 0.13 + 2.0) * 0.7;
    m += cos(time * 0.09 + 1.0) * 0.5;
    return vec2(n, m);
}

vec2 getTrebleMode(float lowTreble, float highTreble, float time) {
    // Treble: modes 5-12, intricate fine patterns
    float n = 5.0 + lowTreble * 3.0 + highTreble * 2.0;
    float m = 6.0 + highTreble * 4.0;
    n += cos(time * 0.17 + 3.0) * 0.8;
    m += sin(time * 0.14 + 2.5) * 0.6;
    return vec2(n, m);
}

vec2 getBeatMode(float beat, float energy, float time) {
    // Beat: dramatic jumps, modes 2-10
    float n = 2.0 + energy * 4.0 + beat * 3.0;
    float m = 3.0 + beat * 5.0 + energy * 2.0;
    n += sin(time * 0.2 + 4.0) * 0.4;
    m += cos(time * 0.15 + 3.5) * 0.5 + beat * 1.5;
    return vec2(n, m);
}

// ============================================================================
// COLORED SAND LAYER - Each layer has its own color!
// ============================================================================

vec4 sandLayer(vec2 uv, float n, float m, float spread, float density, float time,
               vec3 color, float shimmerAmt, float energy, float bass) {
    // Apply spatial warp to break symmetry
    vec2 warpedUV = warpSpace(uv, time, energy, bass);

    vec2 gridUV = warpedUV * density;
    vec2 cellID = floor(gridUV);
    vec2 cellUV = fract(gridUV);

    float sand = 0.0;
    float glow = 0.0;

    // Optimized: single cell lookup instead of 3x3
    vec2 rnd = hash2(cellID);
    float phase = hash(cellID * 0.77) * 6.28;

    float shimmer = 0.85 + 0.15 * sin(time * 3.0 + phase);
    shimmer = mix(1.0, shimmer, shimmerAmt);

    float wobbleX = sin(time * 0.7 + phase) * 0.012 * (1.0 - spread * 0.6);
    float wobbleY = cos(time * 0.5 + phase * 1.3) * 0.012 * (1.0 - spread * 0.6);

    vec2 startPos = (hash2(cellID * 1.3) - 0.5) * 0.07 + vec2(wobbleX, wobbleY);

    vec2 worldPos = (cellID + rnd) / density;
    float pattern = chladniBlend(worldPos, n, m);
    vec2 flowDir = normalize(worldPos + 0.001) * sign(pattern);
    vec2 endPos = worldPos - flowDir * abs(pattern) * 0.12 + vec2(wobbleX, wobbleY) * 0.4;

    float easedSpread = spread * spread * (3.0 - 2.0 * spread);
    vec2 pos = mix(startPos, endPos, easedSpread);

    vec2 localPos = pos * density - cellID;
    float dist = length(localPos - cellUV);

    float size = (0.045 + (1.0 - spread) * 0.02);
    sand = (1.0 - smoothstep(size * 0.5, size, dist)) * shimmer;
    glow = exp(-dist * 12.0) * 0.4 * shimmer;

    sand = clamp(sand, 0.0, 1.0);
    glow = clamp(glow, 0.0, 1.0);

    return vec4(color, sand + glow * 0.5);
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

    float subBass = uBand0;
    float lowBass = uBand1;
    float highBass = uBand2;
    float lowMid = uBand3;
    float midBand = uBand4;
    float highMid = uBand5;
    float lowTreble = uBand6;
    float highTreble = uBand7;

    // ========================================================================
    // FOUR CHLADNI MODES
    // ========================================================================

    vec2 bassNM = getBassMode(subBass, lowBass, highBass, time);
    vec2 midNM = getMidMode(lowMid, midBand, highMid, time);
    vec2 trebleNM = getTrebleMode(lowTreble, highTreble, time);
    vec2 beatNM = getBeatMode(beat, energy, time);

    // ========================================================================
    // SPREAD per layer
    // ========================================================================

    float bassSpread = clamp(bass * 2.0, 0.0, 1.0);
    float midSpread = clamp(mid * 1.8, 0.0, 1.0);
    float trebleSpread = clamp(treble * 1.5, 0.0, 1.0);
    float beatSpread = clamp(beat * 2.5 + energy * 0.5, 0.0, 1.0);

    // ========================================================================
    // FOUR COLORED LAYERS - Each with DISTINCT color
    // ========================================================================

    // BASS: Warm amber/orange
    vec3 bassColor = vec3(1.0, 0.7, 0.3);
    vec4 layerBass = sandLayer(uv, bassNM.x, bassNM.y, bassSpread, 50.0, time, bassColor, 0.3, energy, bass);

    // MID: Cool cyan/teal
    vec3 midColor = vec3(0.3, 0.9, 0.8);
    vec4 layerMid = sandLayer(uv * 1.02, midNM.x, midNM.y, midSpread, 60.0, time * 1.1, midColor, 0.5, energy, mid);

    // TREBLE: Soft pink/magenta
    vec3 trebleColor = vec3(1.0, 0.5, 0.8);
    vec4 layerTreble = sandLayer(uv * 0.98, trebleNM.x, trebleNM.y, trebleSpread, 75.0, time * 0.9, trebleColor, 0.7, energy, treble);

    // BEAT: Electric purple/violet
    vec3 beatColor = vec3(0.7, 0.3, 1.0);
    vec4 layerBeat = sandLayer(uv * 1.01, beatNM.x, beatNM.y, beatSpread, 65.0, time * 1.15, beatColor, 0.4 + beat * 0.4, energy, beat);

    // ========================================================================
    // COMPOSITING - Layer the colors
    // ========================================================================

    // Dark plate background
    vec3 plateColor = vec3(0.02, 0.02, 0.04);

    // Add subtle Chladni pattern glow to background
    float bgPattern = abs(chladniBlend(uv, bassNM.x, bassNM.y));
    plateColor += vec3(0.03, 0.02, 0.05) * bgPattern * energy;

    vec3 color = plateColor;

    // Blend layers additively based on their alpha (sand amount)
    // Scale by audio intensity so layers appear when their frequency is active
    color += layerBass.rgb * layerBass.a * (0.3 + bass * 0.7);
    color += layerMid.rgb * layerMid.a * (0.2 + mid * 0.8);
    color += layerTreble.rgb * layerTreble.a * (0.15 + treble * 0.85);
    color += layerBeat.rgb * layerBeat.a * (0.1 + beat * 0.9);

    // ========================================================================
    // EFFECTS
    // ========================================================================

    // Edge glow (combined from all layers)
    float totalSand = layerBass.a + layerMid.a + layerTreble.a + layerBeat.a;
    float edge = length(vec2(dFdx(totalSand), dFdy(totalSand)));
    color += vec3(1.0, 1.0, 1.0) * edge * 0.8;

    // Sparkle
    float sparkleNoise = noise(uv * 150.0 + time * 1.5);
    float sparkle = smoothstep(0.92, 0.98, sparkleNoise) * min(totalSand, 1.0);
    color += vec3(1.0, 1.0, 1.0) * sparkle * 0.5;

    // Beat pulse from center
    float pulseGlow = exp(-length(uv) * 2.0) * beat * 0.3;
    color += vec3(0.6, 0.3, 0.8) * pulseGlow;

    // Overall energy brightness
    color *= 0.9 + energy * 0.2;

    // ========================================================================
    // VIGNETTE
    // ========================================================================

    float vig = 1.0 - length(uv) * 0.3;
    color *= smoothstep(0.0, 1.0, vig);

    // ========================================================================
    // FINAL
    // ========================================================================

    color = clamp(color, 0.0, 1.0);
    color += (hash(fragCoord + time * 0.01) - 0.5) / 255.0;

    fragColor = vec4(color, 1.0);
}
