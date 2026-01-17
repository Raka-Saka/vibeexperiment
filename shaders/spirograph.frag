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
// SPIROGRAPH EPICYCLES
// Mathematical Foundation: Fourier series visualization
// x = sum(r_i * cos(f_i * t + phi_i))
// y = sum(r_i * sin(f_i * t + phi_i))
// ============================================================================

// Compute spirograph position at time t with given parameters
vec2 spirograph(float t, float r1, float r2, float r3, float f1, float f2, float f3) {
    float x = r1 * cos(f1 * t) + r2 * cos(f2 * t) + r3 * cos(f3 * t);
    float y = r1 * sin(f1 * t) + r2 * sin(f2 * t) + r3 * sin(f3 * t);
    return vec2(x, y);
}

// Extended spirograph with more circles for complex patterns
vec2 spirographExtended(float t, float bands[8]) {
    vec2 pos = vec2(0.0);

    // 8 nested circles, each controlled by a frequency band
    for (int i = 0; i < 8; i++) {
        float freq = float(i + 1) * 1.5;
        float radius = 0.15 * (0.3 + bands[i] * 0.7) / float(i + 1);
        float phase = float(i) * PI * 0.25;
        pos.x += radius * cos(freq * t + phase);
        pos.y += radius * sin(freq * t + phase);
    }

    return pos;
}

// Distance to a line segment
float distToSegment(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// HSV to RGB conversion
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Smooth noise for variation
float hash(float n) {
    return fract(sin(n) * 43758.5453);
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

    // Collect bands into array
    float bands[8];
    bands[0] = uBand0;
    bands[1] = uBand1;
    bands[2] = uBand2;
    bands[3] = uBand3;
    bands[4] = uBand4;
    bands[5] = uBand5;
    bands[6] = uBand6;
    bands[7] = uBand7;

    // Background - dark with subtle gradient
    vec3 bgColor = vec3(0.02, 0.02, 0.05);
    bgColor += vec3(0.03, 0.02, 0.04) * (1.0 - length(uv));

    vec3 color = bgColor;

    // ========================================================================
    // SPIROGRAPH PARAMETERS - Audio controlled
    // ========================================================================

    // Main circles - radii controlled by bass/mid/treble
    float r1 = 0.25 + bass * 0.15;
    float r2 = 0.15 + mid * 0.12;
    float r3 = 0.08 + treble * 0.08;

    // Frequencies - create interesting ratios
    float baseSpeed = 0.5 + energy * 0.5;
    float f1 = 1.0 * baseSpeed;
    float f2 = (2.0 + floor(bass * 3.0)) * baseSpeed;  // 2-5 based on bass
    float f3 = (3.0 + floor(treble * 4.0)) * baseSpeed; // 3-7 based on treble

    // ========================================================================
    // DRAW SPIROGRAPH TRAILS
    // ========================================================================

    // Trail length based on energy
    // Reduced trail length for mobile performance
    float trailLength = 40.0 + energy * 40.0;
    float trailStep = 0.03;

    // Draw multiple layers with different parameters
    for (int layer = 0; layer < 3; layer++) {
        float layerOffset = float(layer) * 0.33;
        float layerScale = 1.0 - float(layer) * 0.15;

        // Adjust frequencies per layer
        float lf1 = f1 * (1.0 + layerOffset * 0.5);
        float lf2 = f2 * (1.0 - layerOffset * 0.3);
        float lf3 = f3 * (1.0 + layerOffset * 0.2);

        float lr1 = r1 * layerScale;
        float lr2 = r2 * layerScale;
        float lr3 = r3 * layerScale;

        // Draw trail as series of line segments
        float minDist = 1000.0;
        float closestT = 0.0;

        vec2 prevPos = spirograph(time, lr1, lr2, lr3, lf1, lf2, lf3);

        for (float i = 0.0; i < 80.0; i += 1.0) {
            if (i >= trailLength) break;
            float t = time - i * trailStep;
            vec2 pos = spirograph(t, lr1, lr2, lr3, lf1, lf2, lf3);

            float d = distToSegment(uv, prevPos, pos);
            if (d < minDist) {
                minDist = d;
                closestT = i / trailLength;
            }

            prevPos = pos;
        }

        // Trail thickness - thicker at head, thinner at tail
        float thickness = 0.008 + beat * 0.006;
        thickness *= (1.0 - closestT * 0.7);

        // Trail intensity - fade toward tail
        float intensity = smoothstep(thickness * 2.0, thickness * 0.3, minDist);
        intensity *= (1.0 - closestT * 0.85);

        // Layer color - hue based on layer and spectral centroid
        float spectralCentroid = (bass * 0.2 + mid * 0.5 + treble * 0.8);
        float hue = layerOffset + spectralCentroid * 0.3 + time * 0.02;
        float sat = 0.7 + energy * 0.3;
        float val = 0.8 + beat * 0.2;

        vec3 trailColor = hsv2rgb(vec3(hue, sat, val));

        // Add glow
        float glow = exp(-minDist * 60.0) * 0.5;
        glow *= (1.0 - closestT * 0.6);

        color += trailColor * (intensity + glow) * (0.5 + float(2 - layer) * 0.25);
    }

    // ========================================================================
    // EXTENDED SPIROGRAPH - More complex pattern using all bands
    // ========================================================================

    // Reduced extended trail for performance
    float extTrailLength = 30.0 + energy * 30.0;
    vec2 prevExtPos = spirographExtended(time, bands);
    float minExtDist = 1000.0;
    float closestExtT = 0.0;

    for (float i = 0.0; i < 60.0; i += 1.0) {
        if (i >= extTrailLength) break;
        float t = time - i * 0.025;
        vec2 pos = spirographExtended(t, bands);

        float d = distToSegment(uv, prevExtPos, pos);
        if (d < minExtDist) {
            minExtDist = d;
            closestExtT = i / extTrailLength;
        }

        prevExtPos = pos;
    }

    // Extended trail rendering
    float extThickness = 0.006 + energy * 0.004;
    extThickness *= (1.0 - closestExtT * 0.6);

    float extIntensity = smoothstep(extThickness * 2.0, extThickness * 0.3, minExtDist);
    extIntensity *= (1.0 - closestExtT * 0.8);

    // Golden/warm color for extended pattern
    vec3 extColor = hsv2rgb(vec3(0.1 + time * 0.01, 0.6, 0.9));
    float extGlow = exp(-minExtDist * 80.0) * 0.4;

    color += extColor * (extIntensity + extGlow) * 0.6;

    // ========================================================================
    // DRAWING CIRCLES (the "pen" mechanism)
    // ========================================================================

    // Current spirograph position
    vec2 currentPos = spirograph(time, r1, r2, r3, f1, f2, f3);

    // Draw the nested circles
    float circleGlow = 0.0;

    // Circle 1 (largest)
    vec2 c1 = vec2(0.0);
    float d1 = abs(length(uv - c1) - r1);
    circleGlow += exp(-d1 * 50.0) * 0.15 * bass;

    // Circle 2
    vec2 c2 = c1 + r1 * vec2(cos(f1 * time), sin(f1 * time));
    float d2 = abs(length(uv - c2) - r2);
    circleGlow += exp(-d2 * 60.0) * 0.12 * mid;

    // Circle 3
    vec2 c3 = c2 + r2 * vec2(cos(f2 * time), sin(f2 * time));
    float d3 = abs(length(uv - c3) - r3);
    circleGlow += exp(-d3 * 70.0) * 0.1 * treble;

    // Pen point
    float penDist = length(uv - currentPos);
    float pen = exp(-penDist * 100.0) * (0.5 + beat * 0.5);

    // Circle colors
    color += vec3(0.3, 0.5, 0.8) * circleGlow;
    color += vec3(1.0, 0.9, 0.7) * pen;

    // ========================================================================
    // EFFECTS
    // ========================================================================

    // Center glow on beat
    float centerGlow = exp(-length(uv) * 3.0) * beat * 0.3;
    color += vec3(0.5, 0.3, 0.7) * centerGlow;

    // Subtle rotation effect
    float rotAngle = atan(uv.y, uv.x);
    float rotPattern = sin(rotAngle * 6.0 + time * 0.5) * 0.5 + 0.5;
    color += vec3(0.02, 0.01, 0.03) * rotPattern * energy;

    // Vignette
    float vig = 1.0 - length(uv) * 0.4;
    color *= smoothstep(0.0, 1.0, vig);

    // Final output
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
