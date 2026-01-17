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
// MANDELBROT / JULIA SET MORPHING
// Mathematical Foundation: z(n+1) = z(n)^2 + c
// Animating c creates mesmerizing morphing patterns
// ============================================================================

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Complex multiplication
vec2 cmul(vec2 a, vec2 b) {
    return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// Complex square
vec2 csqr(vec2 z) {
    return vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
}

// Julia set iteration - returns (iteration count, final magnitude, orbit trap distance)
vec3 julia(vec2 z, vec2 c, int maxIter) {
    float minDist = 1000.0;  // Orbit trap

    for (int i = 0; i < 40; i++) {
        if (i >= maxIter) break;

        z = csqr(z) + c;

        // Track minimum distance to axes (orbit trap)
        minDist = min(minDist, min(abs(z.x), abs(z.y)));

        float mag = dot(z, z);
        if (mag > 256.0) {
            // Smooth iteration count
            float smoothIter = float(i) - log2(log2(mag)) + 4.0;
            return vec3(smoothIter, sqrt(mag), minDist);
        }
    }

    return vec3(float(maxIter), length(z), minDist);
}

// Mandelbrot iteration (simplified for performance)
vec3 mandelbrot(vec2 c, int maxIter) {
    vec2 z = vec2(0.0);
    float minDist = 1000.0;

    for (int i = 0; i < 30; i++) {
        if (i >= maxIter) break;

        z = csqr(z) + c;
        minDist = min(minDist, min(abs(z.x), abs(z.y)));

        float mag = dot(z, z);
        if (mag > 256.0) {
            float smoothIter = float(i) - log2(log2(mag)) + 4.0;
            return vec3(smoothIter, sqrt(mag), minDist);
        }
    }

    return vec3(float(maxIter), length(z), minDist);
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
    vec3 bgColor = vec3(0.0, 0.0, 0.02);
    vec3 color = bgColor;

    // ========================================================================
    // FRACTAL PARAMETERS - Audio controlled
    // ========================================================================

    // Julia set c parameter - animate in a path through interesting values
    // The path visits famous Julia set shapes

    // Base orbit - creates smooth morphing through different Julia sets
    float orbitSpeed = 0.15;
    float orbitRadius = 0.7885;  // Golden ratio related

    // Audio modulates the orbit
    float cReal = orbitRadius * cos(time * orbitSpeed) + bass * 0.2;
    float cImag = orbitRadius * sin(time * orbitSpeed * 1.3) + treble * 0.15;

    // Add interesting variations at certain points
    cReal += sin(time * 0.7) * 0.1 * mid;
    cImag += cos(time * 0.5) * 0.08 * energy;

    // Keep c in the interesting range (-2 to 2)
    vec2 c = vec2(
        clamp(cReal, -1.5, 0.5),
        clamp(cImag, -1.2, 1.2)
    );

    // Zoom level - slowly zooms in, resets on beat
    float baseZoom = 1.5;
    float zoomCycle = mod(time * 0.05, 1.0);
    float zoom = baseZoom * (1.0 + zoomCycle * 2.0);

    // Beat can trigger zoom reset for dramatic effect
    if (beat > 0.7) {
        zoom = baseZoom;
    }

    // Pan - slight drift
    vec2 pan = vec2(
        sin(time * 0.1) * 0.3,
        cos(time * 0.08) * 0.2
    );

    // Rotation
    float rotation = time * 0.05 + beat * 0.1;
    float cosR = cos(rotation);
    float sinR = sin(rotation);
    vec2 rotUV = vec2(
        uv.x * cosR - uv.y * sinR,
        uv.x * sinR + uv.y * cosR
    );

    // Final fractal coordinate
    vec2 z = rotUV * zoom + pan;

    // ========================================================================
    // ITERATION COUNT - Audio controlled (optimized for mobile)
    // ========================================================================

    int maxIter = 25 + int(energy * 15.0);

    // ========================================================================
    // COMPUTE JULIA SET
    // ========================================================================

    vec3 result = julia(z, c, maxIter);
    float iterations = result.x;
    float finalMag = result.y;
    float orbitTrap = result.z;

    // ========================================================================
    // COLORING
    // ========================================================================

    // Normalize iteration count
    float normalizedIter = iterations / float(maxIter);

    // Multiple coloring methods, blended by audio

    // Method 1: Classic smooth iteration coloring
    float hue1 = normalizedIter * 3.0 + time * 0.1;
    vec3 color1 = hsv2rgb(vec3(hue1, 0.8, 1.0 - normalizedIter * 0.3));

    // Method 2: Orbit trap coloring
    float trapColor = 1.0 - smoothstep(0.0, 0.5, orbitTrap);
    vec3 color2 = hsv2rgb(vec3(0.6 + orbitTrap, 0.7, trapColor));

    // Method 3: Distance estimation coloring
    float de = log(finalMag) * sqrt(finalMag) / pow(2.0, iterations);
    vec3 color3 = hsv2rgb(vec3(0.1 + de * 10.0, 0.9, 1.0 - exp(-de * 50.0)));

    // Blend methods based on audio
    color = color1 * (0.4 + bass * 0.3);
    color += color2 * (0.3 + mid * 0.3);
    color += color3 * (0.2 + treble * 0.2);

    // Inside the set (didn't escape) - deep color
    if (normalizedIter > 0.99) {
        // Inside coloring based on final position
        float insideHue = atan(result.y, result.x) / (2.0 * PI) + 0.5;
        float insideSat = 0.5 + beat * 0.3;
        float insideVal = 0.1 + energy * 0.2;
        color = hsv2rgb(vec3(insideHue + time * 0.05, insideSat, insideVal));

        // Inner glow based on orbit trap
        color += vec3(0.1, 0.05, 0.15) * (1.0 - orbitTrap * 2.0);
    }

    // ========================================================================
    // BEAT EFFECTS
    // ========================================================================

    // Pulse on beat
    color *= 1.0 + beat * 0.4;

    // Edge glow
    float dist = length(uv);
    float edgeGlow = smoothstep(0.8, 0.4, dist) * beat * 0.3;
    color += vec3(0.3, 0.2, 0.4) * edgeGlow;

    // ========================================================================
    // AUDIO REACTIVE GLOW
    // ========================================================================

    // Bass creates deep glow in low-iteration areas
    float bassGlow = (1.0 - normalizedIter) * bass * 0.3;
    color += vec3(0.2, 0.1, 0.3) * bassGlow;

    // Treble creates sparkle in high-iteration (detailed) areas
    float trebleSparkle = normalizedIter * treble * 0.2;
    color += vec3(0.4, 0.3, 0.5) * trebleSparkle;

    // ========================================================================
    // FINAL EFFECTS
    // ========================================================================

    // Gamma correction for better contrast
    color = pow(color, vec3(0.9));

    // Energy brightness
    color *= 0.85 + energy * 0.3;

    // Subtle vignette
    float vig = 1.0 - dist * 0.25;
    color *= smoothstep(0.0, 1.0, vig);

    // Clamp and output
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
