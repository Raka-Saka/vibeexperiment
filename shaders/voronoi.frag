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
// VORONOI FLOW FIELDS
// Mathematical Foundation: Partition space based on distance to seed points
// Each cell colored based on which seed is nearest
// ============================================================================

// Hash functions for pseudo-random seed positions
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p) * 43758.5453);
}

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Simplex-style noise for flow field
vec2 flowNoise(vec2 p, float time) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    vec2 a = hash2(i) * 2.0 - 1.0;
    vec2 b = hash2(i + vec2(1.0, 0.0)) * 2.0 - 1.0;
    vec2 c = hash2(i + vec2(0.0, 1.0)) * 2.0 - 1.0;
    vec2 d = hash2(i + vec2(1.0, 1.0)) * 2.0 - 1.0;

    // Add time-based rotation to flow
    float angle = time * 0.3;
    mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y) * rot;
}

// Voronoi with flow field - returns (distance to nearest, distance to second nearest, cell ID)
vec4 voronoi(vec2 p, float time, float flowStrength, float bass) {
    vec2 n = floor(p);
    vec2 f = fract(p);

    float md = 8.0;   // min distance to nearest
    float md2 = 8.0;  // min distance to second nearest
    vec2 mg = vec2(0.0); // cell position

    // Search 3x3 neighborhood
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash2(n + g);

            // Flow field animation
            vec2 flow = flowNoise((n + g) * 0.5, time) * flowStrength;
            flow *= (0.5 + bass * 0.5);

            // Animate seed points
            o = 0.5 + 0.4 * sin(time * 0.5 + 6.2831 * o + flow.x);
            o += flow * 0.3;

            vec2 r = g + o - f;
            float d = dot(r, r);

            if (d < md) {
                md2 = md;
                md = d;
                mg = n + g;
            } else if (d < md2) {
                md2 = d;
            }
        }
    }

    return vec4(sqrt(md), sqrt(md2), mg);
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

    // Background
    vec3 bgColor = vec3(0.02, 0.03, 0.05);

    // ========================================================================
    // VORONOI PARAMETERS
    // ========================================================================

    // Cell count increases with energy
    float cellScale = 4.0 + energy * 4.0;

    // Flow strength controlled by bass
    float flowStrength = 0.5 + bass * 1.5;

    // Scale UV for Voronoi
    vec2 vUV = uv * cellScale;

    // Get Voronoi data
    vec4 v = voronoi(vUV, time, flowStrength, bass);
    float d1 = v.x;  // distance to nearest
    float d2 = v.y;  // distance to second nearest
    vec2 cellID = v.zw;

    // ========================================================================
    // CELL COLORING
    // ========================================================================

    // Cell color based on ID and frequency bands
    float cellHash = hash(cellID);

    // Map cell to frequency band
    int bandIndex = int(cellHash * 8.0);
    float bandValue = 0.0;
    if (bandIndex == 0) bandValue = uBand0;
    else if (bandIndex == 1) bandValue = uBand1;
    else if (bandIndex == 2) bandValue = uBand2;
    else if (bandIndex == 3) bandValue = uBand3;
    else if (bandIndex == 4) bandValue = uBand4;
    else if (bandIndex == 5) bandValue = uBand5;
    else if (bandIndex == 6) bandValue = uBand6;
    else bandValue = uBand7;

    // Base hue from cell ID, shifted by time
    float hue = cellHash + time * 0.02;

    // Saturation varies with mid frequencies
    float sat = 0.5 + mid * 0.4;

    // Value (brightness) from cell's assigned band
    float val = 0.2 + bandValue * 0.7;

    vec3 cellColor = hsv2rgb(vec3(hue, sat, val));

    // ========================================================================
    // CELL EFFECTS
    // ========================================================================

    // Cell interior gradient
    float cellGradient = 1.0 - smoothstep(0.0, 0.5, d1);

    // Edge detection - border between cells
    float edge = d2 - d1;
    float borderWidth = 0.05 + beat * 0.05;
    float border = smoothstep(borderWidth, borderWidth * 0.3, edge);

    // Border glow on beat
    float borderGlow = smoothstep(borderWidth * 2.0, 0.0, edge) * beat;

    // Cell pulsing with its assigned frequency band
    float pulse = 0.8 + bandValue * 0.4;

    // ========================================================================
    // COMPOSE COLOR
    // ========================================================================

    vec3 color = bgColor;

    // Cell fill with gradient
    color = mix(color, cellColor * pulse, cellGradient * 0.8);

    // Bright borders
    vec3 borderColor = hsv2rgb(vec3(hue + 0.5, 0.3, 1.0));
    color = mix(color, borderColor, border * 0.7);

    // Border glow
    color += borderColor * borderGlow * 0.5;

    // ========================================================================
    // SECOND VORONOI LAYER (larger scale, subtler)
    // ========================================================================

    vec2 vUV2 = uv * (cellScale * 0.4);
    vec4 v2 = voronoi(vUV2, time * 0.7, flowStrength * 0.5, bass);

    float edge2 = v2.y - v2.x;
    float border2 = smoothstep(0.08, 0.02, edge2);

    // Subtle large-scale structure
    color += vec3(0.1, 0.15, 0.2) * border2 * 0.3 * energy;

    // ========================================================================
    // THIRD VORONOI LAYER (smaller scale, detailed)
    // ========================================================================

    vec2 vUV3 = uv * (cellScale * 2.5);
    vec4 v3 = voronoi(vUV3, time * 1.5, flowStrength * 0.3, treble);

    float edge3 = v3.y - v3.x;
    float border3 = smoothstep(0.04, 0.01, edge3);

    // Fine detail layer
    color += vec3(0.2, 0.1, 0.15) * border3 * 0.2 * treble;

    // ========================================================================
    // GLOBAL EFFECTS
    // ========================================================================

    // Radial energy wave on beat
    float dist = length(uv);
    float wave = sin(dist * 20.0 - time * 3.0) * 0.5 + 0.5;
    wave *= exp(-dist * 2.0) * beat;
    color += vec3(0.3, 0.2, 0.4) * wave * 0.4;

    // Center glow
    float centerGlow = exp(-dist * 2.5) * energy * 0.3;
    color += vec3(0.2, 0.3, 0.5) * centerGlow;

    // Overall energy brightness
    color *= 0.8 + energy * 0.3;

    // Vignette
    float vig = 1.0 - dist * 0.35;
    color *= smoothstep(0.0, 1.0, vig);

    // Final output
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
