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
// PENDULUM WAVES
// Mathematical Foundation: N pendulums with periods forming harmonic series
// theta_i(t) = A * sin(2*PI*t / T_i), where T_i = T_0 / (n + i)
// Creates beautiful interference patterns as pendulums go in/out of phase
// ============================================================================

// HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Calculate pendulum position at time t
// Returns angle in radians
float pendulumAngle(float pendulumIndex, float totalPendulums, float time, float amplitude, float baseFreq) {
    // Period decreases as index increases (harmonic series)
    float period = 1.0 / (baseFreq + pendulumIndex * 0.1);
    return amplitude * sin(TAU * time / period);
}

// Soft circle for pendulum bob
float pendulumBob(vec2 p, vec2 bobPos, float radius) {
    float d = length(p - bobPos);
    return smoothstep(radius, radius * 0.3, d);
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

    // Background - dark with gradient
    vec3 bgColor = vec3(0.02, 0.02, 0.04);
    float bgGrad = 1.0 - abs(uv.y) * 0.5;
    bgColor += vec3(0.01, 0.02, 0.03) * bgGrad;

    vec3 color = bgColor;

    // ========================================================================
    // PENDULUM PARAMETERS (optimized for mobile)
    // ========================================================================

    // Number of pendulums (reduced for performance)
    float numPendulums = 10.0 + energy * 5.0;

    // Pendulum length and amplitude
    float pendulumLength = 0.5 + bass * 0.2;
    float amplitude = 0.8 + mid * 0.4;

    // Base frequency - controls how fast the pattern evolves
    float baseFreq = 0.3 + treble * 0.3;

    // Spacing between pendulums
    float spacing = 1.6 / numPendulums;

    // Trail persistence (reduced for performance)
    float trailLength = 8.0 + energy * 6.0;
    float trailFade = 0.8;

    // ========================================================================
    // RENDER PENDULUM ARRAY (TOP VIEW - looking down at swinging pendulums)
    // ========================================================================

    float totalIntensity = 0.0;
    vec3 totalColor = vec3(0.0);

    // Anchor point (top of screen)
    float anchorY = 0.45;

    for (float i = 0.0; i < 15.0; i += 1.0) {
        if (i >= numPendulums) break;

        // Pendulum x position (spread across screen)
        float pendulumX = (i / numPendulums - 0.5) * 1.4;

        // Get current swing angle
        float angle = pendulumAngle(i, numPendulums, time, amplitude, baseFreq);

        // Audio modulation per pendulum
        float bandIdx = mod(i, 8.0);
        float bandValue = 0.0;
        if (bandIdx < 1.0) bandValue = uBand0;
        else if (bandIdx < 2.0) bandValue = uBand1;
        else if (bandIdx < 3.0) bandValue = uBand2;
        else if (bandIdx < 4.0) bandValue = uBand3;
        else if (bandIdx < 5.0) bandValue = uBand4;
        else if (bandIdx < 6.0) bandValue = uBand5;
        else if (bandIdx < 7.0) bandValue = uBand6;
        else bandValue = uBand7;

        // Modulate amplitude with audio band
        float modAmplitude = amplitude * (0.7 + bandValue * 0.5);

        // Calculate bob position
        float len = pendulumLength * (0.8 + bandValue * 0.3);
        vec2 anchorPos = vec2(pendulumX, anchorY);
        vec2 bobPos = anchorPos + vec2(sin(angle) * len, -cos(angle) * len);

        // Bob size
        float bobRadius = 0.025 + beat * 0.01;

        // Draw pendulum bob
        float bob = pendulumBob(uv, bobPos, bobRadius);

        // Glow around bob
        float dist = length(uv - bobPos);
        float glow = exp(-dist * 30.0) * 0.6;

        // Color based on pendulum index and velocity
        float velocity = cos(TAU * time / (1.0 / (baseFreq + i * 0.1)));  // Derivative of sin
        float hue = i / numPendulums * 0.7 + time * 0.02;
        float sat = 0.6 + abs(velocity) * 0.3;
        float val = 0.7 + bandValue * 0.3;

        vec3 pendulumColor = hsv2rgb(vec3(hue, sat, val));

        // Motion blur / trail effect (reduced iterations)
        for (float t = 0.0; t < 14.0; t += 1.0) {
            if (t >= trailLength) break;

            float pastTime = time - t * 0.025;
            float pastAngle = pendulumAngle(i, numPendulums, pastTime, modAmplitude, baseFreq);
            vec2 pastBobPos = anchorPos + vec2(sin(pastAngle) * len, -cos(pastAngle) * len);

            // Smooth fade with extra end fade to prevent abrupt cutoff
            float normalizedT = t / trailLength;
            float endFade = 1.0 - smoothstep(0.6, 1.0, normalizedT);
            float trailDist = length(uv - pastBobPos);
            float trailGlow = exp(-trailDist * 50.0) * pow(trailFade, t) * endFade * 0.2;

            color += pendulumColor * trailGlow;
        }

        // Add current bob
        totalIntensity += bob + glow;
        totalColor += pendulumColor * (bob + glow);

        // Draw pendulum string (faint line)
        vec2 toAnchor = anchorPos - uv;
        vec2 toBob = bobPos - uv;
        float stringProj = dot(-toAnchor, normalize(bobPos - anchorPos));
        float stringLen = length(bobPos - anchorPos);

        if (stringProj > 0.0 && stringProj < stringLen) {
            vec2 closestOnString = anchorPos + normalize(bobPos - anchorPos) * stringProj;
            float stringDist = length(uv - closestOnString);
            float stringLine = exp(-stringDist * 200.0) * 0.15;
            color += vec3(0.5, 0.5, 0.6) * stringLine;
        }
    }

    // Add accumulated pendulum colors
    if (totalIntensity > 0.001) {
        color += totalColor * 0.8;
    }

    // ========================================================================
    // WAVE PATTERN VISUALIZATION (shows the interference pattern)
    // ========================================================================

    // Draw the wave envelope at the bottom
    float waveY = -0.35;
    float waveHeight = 0.15;

    float waveSum = 0.0;
    for (float i = 0.0; i < 15.0; i += 1.0) {
        if (i >= numPendulums) break;
        float angle = pendulumAngle(i, numPendulums, time, amplitude, baseFreq);
        waveSum += sin(angle);
    }
    waveSum /= numPendulums;

    // Map uv.x to wave position
    float waveX = uv.x;
    float waveVal = 0.0;
    for (float i = 0.0; i < 15.0; i += 1.0) {
        if (i >= numPendulums) break;
        float pendulumX = (i / numPendulums - 0.5) * 1.4;
        float dist = abs(waveX - pendulumX);
        if (dist < spacing) {
            float angle = pendulumAngle(i, numPendulums, time, amplitude, baseFreq);
            waveVal += sin(angle) * (1.0 - dist / spacing);
        }
    }

    // Draw wave line
    float waveLineY = waveY + waveVal * waveHeight * 0.3;
    float waveDist = abs(uv.y - waveLineY);
    float waveLine = exp(-waveDist * 80.0) * 0.5;
    color += vec3(0.4, 0.6, 0.8) * waveLine * (0.5 + energy * 0.5);

    // ========================================================================
    // BEAT EFFECTS
    // ========================================================================

    // Flash on beat
    color += vec3(0.2, 0.15, 0.25) * beat * 0.3 * exp(-length(uv) * 2.0);

    // Pulse rings from center
    float dist = length(uv);
    float pulse = sin(dist * 20.0 - time * 5.0) * 0.5 + 0.5;
    pulse *= exp(-dist * 3.0) * beat * 0.2;
    color += vec3(0.3, 0.4, 0.5) * pulse;

    // ========================================================================
    // ANCHOR BAR
    // ========================================================================

    float barDist = abs(uv.y - anchorY);
    float bar = exp(-barDist * 100.0) * 0.3;
    color += vec3(0.4, 0.4, 0.5) * bar;

    // ========================================================================
    // FINAL EFFECTS
    // ========================================================================

    // Energy brightness
    color *= 0.85 + energy * 0.25;

    // Vignette
    float vig = 1.0 - length(uv) * 0.3;
    color *= smoothstep(0.0, 1.0, vig);

    // Clamp and output
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, 1.0);
}
