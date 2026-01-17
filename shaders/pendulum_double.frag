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

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Approximate double pendulum motion with coupled oscillators
// Real double pendulum would need physics simulation, this is an artistic approximation
vec2 doublePendulumAngles(float time, float idx, float energy, float bass, float mid) {
    // First arm - slower, larger swings
    float freq1 = 0.7 + idx * 0.05;
    float amp1 = 0.8 + bass * 0.4;
    float angle1 = amp1 * sin(time * freq1) * cos(time * freq1 * 0.3);

    // Second arm - faster, chaotic coupling
    float freq2 = 1.8 + idx * 0.1 + mid * 0.5;
    float amp2 = 1.2 + energy * 0.5;
    // Coupling creates chaos-like behavior
    float coupling = sin(angle1 * 2.0 + time * 0.5);
    float angle2 = amp2 * sin(time * freq2 + coupling) * (0.8 + 0.4 * sin(time * 0.3));

    return vec2(angle1, angle2);
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

    vec3 color = vec3(0.02, 0.02, 0.05);

    // Parameters
    float numPendulums = 4.0 + energy * 2.0;
    float len1 = 0.2 + bass * 0.05;
    float len2 = 0.18 + mid * 0.04;
    float anchorY = 0.35;

    // Draw pendulums
    for (float i = 0.0; i < 6.0; i += 1.0) {
        if (i >= numPendulums) break;

        float x = (i / numPendulums - 0.5) * 1.0;
        vec2 anchor = vec2(x, anchorY);

        // Audio band
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

        vec2 angles = doublePendulumAngles(time, i, energy, bass, mid);

        // First joint position
        float l1 = len1 * (0.9 + bandValue * 0.2);
        vec2 joint1 = anchor + l1 * vec2(sin(angles.x), -cos(angles.x));

        // Second joint (end) position
        float l2 = len2 * (0.9 + bandValue * 0.2);
        vec2 joint2 = joint1 + l2 * vec2(sin(angles.x + angles.y), -cos(angles.x + angles.y));

        // Colors for this pendulum
        float hue1 = i / numPendulums * 0.5 + time * 0.02;
        float hue2 = hue1 + 0.15;
        vec3 color1 = hsv2rgb(vec3(hue1, 0.7, 0.9));
        vec3 color2 = hsv2rgb(vec3(hue2, 0.8, 0.95));

        // Draw trail for end point (the chaotic part) with smooth end fade
        for (float t = 1.0; t < 20.0; t += 1.0) {
            float pastTime = time - t * 0.015;
            vec2 pastAngles = doublePendulumAngles(pastTime, i, energy, bass, mid);
            vec2 pastJoint1 = anchor + l1 * vec2(sin(pastAngles.x), -cos(pastAngles.x));
            vec2 pastJoint2 = pastJoint1 + l2 * vec2(sin(pastAngles.x + pastAngles.y), -cos(pastAngles.x + pastAngles.y));

            float trailDist = length(uv - pastJoint2);
            float normalizedT = t / 20.0;
            float fade = 1.0 - normalizedT;
            float endFade = 1.0 - smoothstep(0.6, 1.0, normalizedT);
            float trailGlow = exp(-trailDist * 50.0) * fade * endFade * 0.12;
            color += color2 * trailGlow;
        }

        // Draw first arm with end fade
        for (float s = 0.0; s < 1.0; s += 0.05) {
            vec2 armPoint = mix(anchor, joint1, s);
            float armDist = length(uv - armPoint);
            float armEndFade = 1.0 - smoothstep(0.8, 1.0, s);
            float armLine = exp(-armDist * 80.0) * 0.2 * armEndFade;
            color += color1 * armLine * 0.5;
        }

        // Draw second arm with end fade
        for (float s = 0.0; s < 1.0; s += 0.05) {
            vec2 armPoint = mix(joint1, joint2, s);
            float armDist = length(uv - armPoint);
            float armEndFade = 1.0 - smoothstep(0.8, 1.0, s);
            float armLine = exp(-armDist * 80.0) * 0.2 * armEndFade;
            color += color2 * armLine * 0.5;
        }

        // Draw joints
        float jointSize = 0.02 + beat * 0.005;

        // First joint
        float j1Dist = length(uv - joint1);
        float j1 = smoothstep(jointSize, jointSize * 0.4, j1Dist);
        float j1Glow = exp(-j1Dist * 30.0) * 0.4;
        color += color1 * (j1 + j1Glow);

        // Second joint (end point)
        float j2Dist = length(uv - joint2);
        float j2 = smoothstep(jointSize * 1.2, jointSize * 0.5, j2Dist);
        float j2Glow = exp(-j2Dist * 25.0) * 0.5;
        color += color2 * (j2 + j2Glow);

        // Anchor point
        float anchorDist = length(uv - anchor);
        float anchorDot = exp(-anchorDist * 50.0) * 0.3;
        color += vec3(0.5, 0.5, 0.6) * anchorDot;
    }

    // Anchor bar
    float barDist = abs(uv.y - anchorY);
    if (abs(uv.x) < 0.6) {
        float bar = exp(-barDist * 60.0) * 0.25;
        color += vec3(0.4, 0.4, 0.5) * bar;
    }

    // Beat pulse
    color *= 1.0 + beat * 0.3;

    // Vignette
    float vig = 1.0 - length(uv) * 0.3;
    color *= smoothstep(0.0, 1.0, vig);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
