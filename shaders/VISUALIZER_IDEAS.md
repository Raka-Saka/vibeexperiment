they are ewither redundant or not# Math-Based Audio Visualizer Ideas

This document describes mathematically-grounded visualizations that can be implemented as fragment shaders, similar to the Cymatics/Chladni pattern-based "Resonance" visualizer.

---

## 1. Lissajous Figures (Harmonograph)

**Mathematical Foundation:**
```
x(t) = A * sin(a*t + delta)
y(t) = B * sin(b*t)
```

When a/b is a rational number, you get beautiful closed curves. Different frequency ratios create different patterns:
- 1:1 - circle/ellipse
- 1:2 - figure-8
- 2:3 - pretzel shape
- 3:4 - complex knot

**Audio Mapping:**
- `a` frequency controlled by bass
- `b` frequency controlled by treble
- `delta` phase shift controlled by beat
- Line thickness controlled by energy
- Colors shift based on spectral centroid

**Visual Effect:** Elegant, harmonograph-style curves that dance and breathe with the music.

---

## 2. Voronoi Flow Fields

**Mathematical Foundation:**
Voronoi diagrams partition space based on distance to seed points:
```
For each pixel, find the nearest seed point
Color based on distance/which seed is nearest
```

**Audio Mapping:**
- Seed points move in flow fields driven by bass
- Cell colors determined by frequency bands
- Cell boundaries glow on beat
- Seed count increases with energy
- Cells pulse/breathe with rhythm

**Visual Effect:** Organic cellular patterns that flow and reorganize with the music.

---

## 3. Strange Attractors

**Mathematical Foundation:**
Chaotic systems like Lorenz, Rössler, or Clifford attractors:

Lorenz:
```
dx/dt = sigma * (y - x)
dy/dt = x * (rho - z) - y
dz/dt = x * y - beta * z
```

**Audio Mapping:**
- `sigma`, `rho`, `beta` parameters controlled by frequency bands
- Rotation around the attractor controlled by time
- Point density controlled by energy
- Color cycling speed controlled by beat
- 3D perspective depth controlled by bass

**Visual Effect:** Hypnotic, infinitely complex patterns that never repeat exactly.

---

## 4. Reaction-Diffusion (Turing Patterns)

**Mathematical Foundation:**
Gray-Scott model:
```
du/dt = Du * laplacian(u) - u*v^2 + f*(1-u)
dv/dt = Dv * laplacian(v) + u*v^2 - (f+k)*v
```

**Audio Mapping:**
- Feed rate `f` controlled by bass (creates spots vs stripes)
- Kill rate `k` controlled by treble
- Diffusion speed controlled by energy
- Pattern seed locations at beat hits
- Color palette shifts with spectral content

**Visual Effect:** Living, breathing organic patterns like coral, zebra stripes, or leopard spots.

---

## 5. Fractal Flames

**Mathematical Foundation:**
Iterated Function Systems (IFS) with nonlinear variations:
```
(x', y') = sum of weighted variations applied to (x, y)
```

Variations include sinusoidal, spherical, swirl, horseshoe, etc.

**Audio Mapping:**
- Variation weights controlled by frequency bands
- Rotation angle controlled by bass
- Zoom level controlled by energy
- Color palette position controlled by treble
- Symmetry type changes with beat

**Visual Effect:** Ethereal, flame-like fractal patterns with infinite detail.

---

## 6. Pendulum Waves

**Mathematical Foundation:**
N pendulums with periods that form a harmonic series:
```
theta_i(t) = A * sin(2*PI*t / T_i)
T_i = T_0 / (n + i)
```

Creates beautiful interference patterns as pendulums go in and out of phase.

**Audio Mapping:**
- Number of pendulums controlled by complexity
- Swing amplitude controlled by bass
- Phase offset controlled by beat
- Pendulum color gradient based on frequency
- Trail persistence controlled by energy

**Visual Effect:** Mesmerizing wave patterns, like those famous pendulum art installations.

---

## 7. Spirograph Epicycles

**Mathematical Foundation:**
Nested circular motion:
```
x = sum(r_i * cos(f_i * t + phi_i))
y = sum(r_i * sin(f_i * t + phi_i))
```

Fourier series visualization - any shape can be drawn with enough circles!

**Audio Mapping:**
- Circle radii controlled by spectrum bands
- Rotation frequencies from bass to treble mapping
- Trail length controlled by energy
- Color from spectral centroid
- Beat triggers new trail start

**Visual Effect:** Intricate, spirograph-like patterns that evolve continuously.

---

## 8. Wave Interference (Ripples)

**Mathematical Foundation:**
Superposition of circular waves:
```
height = sum(A_i * sin(k*r_i - omega*t + phi_i))
```
where r_i is distance from wave source i.

**Audio Mapping:**
- Wave sources appear on beat
- Wave frequency from treble
- Amplitude from bass
- Decay rate from energy
- Color from spectral content

**Visual Effect:** Beautiful interference patterns like raindrops on water.

---

## 9. Moiré Patterns

**Mathematical Foundation:**
Overlapping periodic patterns with slight offset/rotation:
```
pattern1 = sin(x * f1 + offset1)
pattern2 = sin(x * f2 + offset2)
result = pattern1 * pattern2
```

**Audio Mapping:**
- Frequency ratio controlled by dominant frequencies
- Rotation angle between patterns from bass
- Offset controlled by time and beat
- Color bands from frequency spectrum
- Intensity from energy

**Visual Effect:** Psychedelic, shifting patterns that seem to move independently of the music.

---

## 10. Mandelbrot/Julia Set Morphing

**Mathematical Foundation:**
```
z(n+1) = z(n)^2 + c
```

By animating `c` in Julia sets or zooming into Mandelbrot, create infinite detail.

**Audio Mapping:**
- Real part of c controlled by bass
- Imaginary part of c controlled by treble
- Zoom level controlled by cumulative energy
- Color palette shift from beat
- Iteration depth from overall volume

**Visual Effect:** Infinite fractal zoom that responds to music dynamics.

---

## 11. Phyllotaxis (Sunflower Spirals)

**Mathematical Foundation:**
Golden angle arrangement:
```
r = c * sqrt(n)
theta = n * phi  // phi = golden angle = 137.5°
```

**Audio Mapping:**
- Particle count grows with energy
- Spiral tightness from bass
- Particle size from beat
- Color gradient from frequency
- Rotation speed from treble

**Visual Effect:** Natural, organic spiral patterns like sunflower seeds or pinecones.

---

## 12. Cellular Automata (Rule 110, Game of Life)

**Mathematical Foundation:**
State evolution based on neighbor rules:
```
next_state = rule(current_state, neighbors)
```

**Audio Mapping:**
- Rule selection from bass (creates different patterns)
- Update speed from energy
- Initial seed from beat hits
- Color based on cell age
- Cell size from volume

**Visual Effect:** Emergent, evolving patterns that seem alive.

---

## Implementation Priority

Based on visual impact and audio responsiveness:

1. **Lissajous** - Simple, elegant, highly responsive
2. **Wave Interference** - Intuitive audio mapping
3. **Spirograph** - Beautiful trails, natural frequency mapping
4. **Voronoi** - Organic, modern look
5. **Phyllotaxis** - Natural beauty, easy to implement

Each can be implemented as a GLSL fragment shader following the same pattern as `resonance.frag`.

---

## Shader Uniform Interface

All visualizers should use the same uniform interface for consistency:

```glsl
uniform vec2 uSize;      // Canvas size
uniform float uTime;     // Elapsed time
uniform float uBass;     // 0-1 bass level
uniform float uMid;      // 0-1 mid level
uniform float uTreble;   // 0-1 treble level
uniform float uEnergy;   // 0-1 overall energy
uniform float uBeat;     // 0-1 beat intensity
uniform float uBand0-7;  // 8-band spectrum
```

This allows easy switching between visualizers in the Flutter app.
