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
// MOIRE PATTERNS
// Mathematical Foundation: Overlapping periodic patterns with slight offset
// Creates emergent interference patterns that seem to move
// ============================================================================

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Rotate point around origin
vec2 rotate(vec2 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// Concentric circles pattern
float circles(vec2 p, float freq, float phase) {
    float r = length(p);
    return sin(r * freq + phase) * 0.5 + 0.5;
}

// Radial lines pattern
float radial(vec2 p, float freq, float phase) {
    float angle = atan(p.y, p.x);
    return sin(angle * freq + phase) * 0.5 + 0.5;
}

// Linear stripes pattern
float stripes(vec2 p, float freq, float phase) {
    return sin(p.x * freq + phase) * 0.5 + 0.5;
}

// Grid pattern
float grid(vec2 p, float freq) {
    return sin(p.x * freq) * sin(p.y * freq) * 0.5 + 0.5;
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
    vec3 bgColor = vec3(0.02, 0.02, 0.03);
    vec3 color = bgColor;

    // ========================================================================
    // MOIRE PARAMETERS
    // ========================================================================

    // Base frequency controlled by energy
    float baseFreq = 25.0 + energy * 20.0;

    // Rotation angles controlled by bass
    float rotation1 = time * 0.1 + bass * 0.5;
    float rotation2 = -time * 0.08 + bass * 0.3;
    float rotation3 = time * 0.05;

    // Frequency offsets from audio bands
    float freqOffset1 = uBand0 * 5.0;
    float freqOffset2 = uBand2 * 4.0;
    float freqOffset3 = uBand4 * 3.0;
    float freqOffset4 = uBand6 * 4.0;

    // Phase offsets
    float phase1 = time * 2.0;
    float phase2 = time * 1.5 + beat * PI;
    float phase3 = time * 1.2;
    float phase4 = time * 0.8;

    // ========================================================================
    // LAYER 1: CONCENTRIC CIRCLES MOIRE
    // Two sets of circles with slightly different frequencies
    // ========================================================================

    vec2 uv1a = uv;
    vec2 uv1b = uv + vec2(0.02 + bass * 0.03, 0.0);  // Offset second pattern

    float circles1 = circles(uv1a, baseFreq + freqOffset1, phase1);
    float circles2 = circles(uv1b, baseFreq * 1.05 + freqOffset2, phase2);

    // Moire from multiplying patterns
    float moire1 = circles1 * circles2;

    // Color from first moire layer
    vec3 color1 = hsv2rgb(vec3(0.6 + time * 0.01, 0.7, 0.8));
    color += color1 * moire1 * 0.4 * (0.5 + bass * 0.5);

    // ========================================================================
    // LAYER 2: ROTATED STRIPE MOIRE
    // Two sets of stripes at slightly different angles
    // ========================================================================

    vec2 uv2a = rotate(uv, rotation1);
    vec2 uv2b = rotate(uv, rotation1 + 0.05 + treble * 0.1);

    float stripes1 = stripes(uv2a, baseFreq * 0.8 + freqOffset3, phase3);
    float stripes2 = stripes(uv2b, baseFreq * 0.85 + freqOffset4, phase3 * 1.1);

    float moire2 = stripes1 * stripes2;

    vec3 color2 = hsv2rgb(vec3(0.1 + time * 0.015, 0.8, 0.7));
    color += color2 * moire2 * 0.35 * (0.4 + mid * 0.6);

    // ========================================================================
    // LAYER 3: RADIAL MOIRE
    // Radial lines with different frequencies
    // ========================================================================

    float radialFreq = 12.0 + energy * 8.0;
    float radial1 = radial(uv, radialFreq, time);
    float radial2 = radial(uv, radialFreq * 1.1, time * 1.2 + beat);

    float moire3 = radial1 * radial2;

    vec3 color3 = hsv2rgb(vec3(0.8 + time * 0.02, 0.6, 0.9));
    color += color3 * moire3 * 0.25 * treble;

    // ========================================================================
    // LAYER 4: GRID MOIRE
    // Two offset grids
    // ========================================================================

    vec2 uv4a = rotate(uv, rotation3);
    vec2 uv4b = rotate(uv + vec2(0.01), rotation3 + 0.02);

    float gridFreq = baseFreq * 0.6;
    float grid1 = grid(uv4a, gridFreq);
    float grid2 = grid(uv4b, gridFreq * 1.02);

    float moire4 = grid1 * grid2;

    vec3 color4 = hsv2rgb(vec3(0.4 + time * 0.01, 0.5, 0.6));
    color += color4 * moire4 * 0.2 * (0.3 + energy * 0.4);

    // ========================================================================
    // DYNAMIC ZOOM MOIRE
    // Circles that zoom in/out with bass
    // ========================================================================

    float zoom = 1.0 + bass * 0.3 + sin(time * 0.5) * 0.1;
    vec2 uvZoom = uv * zoom;

    float zoomCircles1 = circles(uvZoom, baseFreq * 0.7, time);
    float zoomCircles2 = circles(uvZoom * 1.02, baseFreq * 0.7, time * 1.05);

    float moireZoom = zoomCircles1 * zoomCircles2;

    vec3 colorZoom = hsv2rgb(vec3(0.3 + mid * 0.2, 0.7, 0.8));
    color += colorZoom * moireZoom * 0.15;

    // ========================================================================
    // SPIRAL MOIRE
    // Logarithmic spirals create hypnotic patterns
    // ========================================================================

    float r = length(uv);
    float theta = atan(uv.y, uv.x);

    float spiral1 = sin(theta * 6.0 + r * 30.0 - time * 2.0) * 0.5 + 0.5;
    float spiral2 = sin(theta * 6.0 + r * 31.0 - time * 2.1) * 0.5 + 0.5;

    float moireSpiral = spiral1 * spiral2;

    vec3 colorSpiral = hsv2rgb(vec3(0.9 + treble * 0.1, 0.6, 0.7));
    color += colorSpiral * moireSpiral * 0.2 * (0.3 + beat * 0.5);

    // ========================================================================
    // BEAT EFFECTS
    // ========================================================================

    // Pulse rings on beat
    float beatRing = sin(r * 50.0 - time * 8.0) * 0.5 + 0.5;
    beatRing *= exp(-r * 2.0) * beat;
    color += vec3(0.5, 0.4, 0.6) * beatRing * 0.3;

    // Center flash
    float centerFlash = exp(-r * 5.0) * beat * 0.4;
    color += vec3(0.8, 0.7, 0.9) * centerFlash;

    // ========================================================================
    // FINAL EFFECTS
    // ========================================================================

    // Intensity modulation
    color *= 0.8 + energy * 0.3;

    // Color temperature shift with frequency content
    float warmth = bass * 0.1 - treble * 0.05;
    color.r += warmth * 0.1;
    color.b -= warmth * 0.1;

    // Vignette
    float vig = 1.0 - r * 0.3;
    color *= smoothstep(0.0, 1.0, vig);

    // Clamp and output
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
