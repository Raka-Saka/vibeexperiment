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

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 center = uSize * 0.5;
    vec2 uv = (fragCoord - center) / min(uSize.x, uSize.y);

    float time = uTime;
    float bass = uBass;
    float mid = uMid;
    float energy = uEnergy;
    float beat = uBeat;

    vec3 color = vec3(0.02, 0.02, 0.04);

    // Newton's Cradle parameters
    float numBalls = 5.0;
    float spacing = 0.12;
    float stringLength = 0.4 + bass * 0.1;
    float ballRadius = 0.045 + energy * 0.01;
    float anchorY = 0.35;

    // Swing period synced to a beat-like rhythm
    float swingPeriod = 1.2 - energy * 0.3;
    float phase = mod(time / swingPeriod, 2.0);

    // Draw anchor bar
    float barWidth = (numBalls - 1.0) * spacing + 0.1;
    float barDist = abs(uv.y - anchorY);
    if (abs(uv.x) < barWidth * 0.5 + 0.02) {
        float bar = exp(-barDist * 80.0) * 0.3;
        color += vec3(0.4, 0.4, 0.5) * bar;
    }

    // Draw each ball
    for (float i = 0.0; i < 5.0; i += 1.0) {
        float x = (i - (numBalls - 1.0) * 0.5) * spacing;
        vec2 anchor = vec2(x, anchorY);

        // Calculate swing angle based on position
        float angle = 0.0;
        float maxAngle = 0.7 + beat * 0.3;

        // Left ball swings when phase < 1, right ball when phase >= 1
        if (i == 0.0 && phase < 1.0) {
            // Left ball swinging
            float t = phase;
            angle = -maxAngle * cos(t * PI);
        } else if (i == numBalls - 1.0 && phase >= 1.0) {
            // Right ball swinging
            float t = phase - 1.0;
            angle = maxAngle * cos(t * PI);
        }

        // Add subtle sway to middle balls on impact
        if (i > 0.0 && i < numBalls - 1.0) {
            float impact = 0.0;
            if (phase < 0.1) impact = (0.1 - phase) * 10.0;
            if (phase > 0.9 && phase < 1.1) impact = (1.0 - abs(phase - 1.0) * 10.0);
            angle = sin(i * 0.5 + time * 8.0) * 0.02 * impact;
        }

        // Bob position
        vec2 bobPos = anchor + stringLength * vec2(sin(angle), -cos(angle));

        // Draw string
        vec2 toBob = bobPos - anchor;
        float stringLen = length(toBob);
        for (float s = 0.0; s < 1.0; s += 0.05) {
            vec2 stringPoint = anchor + toBob * s;
            float stringDist = length(uv - stringPoint);
            float stringLine = exp(-stringDist * 120.0) * 0.15;
            color += vec3(0.5, 0.5, 0.6) * stringLine;
        }

        // Draw ball with metallic look
        float dist = length(uv - bobPos);
        float ball = smoothstep(ballRadius, ballRadius * 0.8, dist);

        // Metallic gradient
        vec2 lightDir = normalize(vec2(0.5, 0.8));
        float light = dot(normalize(uv - bobPos), lightDir) * 0.5 + 0.5;

        vec3 ballColor = mix(
            vec3(0.6, 0.6, 0.7),  // Dark silver
            vec3(0.95, 0.95, 1.0), // Bright silver
            light
        );

        // Glow
        float glow = exp(-dist * 20.0) * 0.4;
        vec3 glowColor = hsv2rgb(vec3(0.6 + i * 0.05, 0.3, 0.8));

        color += ballColor * ball;
        color += glowColor * glow * (0.5 + beat * 0.5);

        // Impact flash
        if ((i == 0.0 && phase > 0.95) || (i == numBalls - 1.0 && abs(phase - 1.0) < 0.05)) {
            float flash = exp(-dist * 15.0) * 0.6;
            color += vec3(0.8, 0.7, 0.5) * flash;
        }
    }

    // Beat pulse
    float pulse = exp(-length(uv) * 3.0) * beat * 0.2;
    color += vec3(0.3, 0.25, 0.4) * pulse;

    // Vignette
    float vig = 1.0 - length(uv) * 0.25;
    color *= smoothstep(0.0, 1.0, vig);

    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color, 1.0);
}
