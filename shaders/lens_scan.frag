#version 460 core
#include <flutter/runtime_effect.glsl>

// AI Lens launch — "Glass sweep": a refractive band front radiates from the
// cursor across the frozen frame (lens refraction + chromatic aberration +
// specular ring + brand tint), then settles into a living idle: a field of
// twinkling stars that drift over the frozen frame and shy away from the live
// cursor, plus a gently breathing coloured edge aura. A dragged selection stays
// crisp, undistorted and slightly brighter.
uniform vec2 uResolution;   // logical px
uniform float uTime;        // seconds, continuous (drives tint drift + aura breath)
uniform float uOpenT;       // 0..1 launch progress
uniform vec4 uSel;          // x, y, w, h (logical px); w <= 0 => no selection
uniform vec2 uCursor;       // launch ripple origin in logical px (top-left origin)
uniform vec2 uPointer;      // live cursor in logical px (stars drift away from it)
uniform sampler2D uTexture; // the frozen frame

out vec4 fragColor;

// Brand gradient palette (purple -> pink -> blue -> cyan).
const vec3 C1 = vec3(0.486, 0.227, 0.929);
const vec3 C2 = vec3(0.925, 0.286, 0.600);
const vec3 C3 = vec3(0.231, 0.510, 0.965);
const vec3 C4 = vec3(0.133, 0.827, 0.933);

// Cyclic: C1->C2->C3->C4->C1 in even quarters, so there's no hard seam at the
// fract() wrap (the old 3-segment version jumped C4->C1, showing as a thin
// radial line that slowly rotated with the uTime hue drift).
vec3 palette(float t) {
  t = fract(t);
  if (t < 0.25) return mix(C1, C2, t / 0.25);
  if (t < 0.50) return mix(C2, C3, (t - 0.25) / 0.25);
  if (t < 0.75) return mix(C3, C4, (t - 0.50) / 0.25);
  return mix(C4, C1, (t - 0.75) / 0.25);
}

// Cheap 2D hash -> [0,1).
float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 345.45));
  p += dot(p, p + 34.345);
  return fract(p.x * p.y);
}

// Twinkling, slowly drifting motes laid out one-per-cell, each shying away from
// the cursor [pst]. Inputs are in aspect-square space (x scaled to y) so the
// stars stay round. Returns additive white light.
vec3 starField(vec2 st, vec2 pst, float t) {
  const float CELLS = 7.0;
  vec3 acc = vec3(0.0);
  vec2 cell = floor(st * CELLS);
  for (int y = -1; y <= 1; y++) {
    for (int x = -1; x <= 1; x++) {
      vec2 cid = cell + vec2(float(x), float(y));
      float h  = hash21(cid);
      float h2 = fract(h * 41.3);
      float h3 = fract(h * 73.7);
      // base position in the cell + slow circular drift ("flying").
      vec2 drift = 0.1 * vec2(sin(t * 0.30 + h  * 6.2831),
                               cos(t * 0.24 + h2 * 6.2831));
      vec2 sp = (cid + vec2(h, h2) + drift) / CELLS;
      // push away from the cursor when it comes close.
      vec2 toStar = sp - pst;
      sp += normalize(toStar + 1e-5) * smoothstep(0.22, 0.0, length(toStar)) * 0.025;
      // twinkle: per-star size + brightness pulse (appear / disappear), slow.
      float tw = 0.5 + 0.5 * sin(t * (0.30 + h2 * 0.7) + h3 * 6.2831);
      float dd = length(st - sp);
      float size = (0.0035 + 0.004 * h2) * (0.4 + 0.6 * tw);
      float core = smoothstep(size, 0.0, dd);
      float glow = smoothstep(size * 4.0, 0.0, dd) * 0.25;
      acc += vec3(core + glow) * tw;
    }
  }
  return acc;
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / uResolution;
  float sAsp = uResolution.x / uResolution.y;

  // Aspect-correct position, relative to the cursor (wave origin).
  vec2 cursorUv = uCursor / uResolution;
  vec2 p = (uv - cursorUv) * vec2(sAsp, 1.0);
  float r = length(p);

  // Separate distance from screen centre, used for the edge aura so it always
  // sits at screen perimeter regardless of where the cursor is.
  float rEdge = length((uv - 0.5) * vec2(sAsp, 1.0));

  float prog = uOpenT;
  // Idle factor: ramps in as the launch sweep settles; gates the ambient effects
  // so they don't fight the opening ripple.
  float idle = smoothstep(0.55, 1.0, prog);

  // ── Glass sweep: a refractive band front travels r=0 -> ~1.55 (off corner) ──
  float front = prog * 1.55;
  float d = r - front;                       // signed distance to the wavefront
  float bandW = 0.36;                        // half-width of the band
  float band = smoothstep(bandW, 0.0, abs(d));

  // Lens refraction: bend samples across the band — the glass-sheet look.
  vec2 radial = normalize(p + 1e-5);
  vec2 offset = radial * (-d) * 5.5 * band * 0.032;
  offset.x /= sAsp;                          // un-aspect back to UV space

  float ring = band * (0.7 + 0.3 * sin(prog * 40.0)); // pulsed specular ring
  float ca = band * 0.9;                              // chromatic aberration mag

  vec2 duv = uv + offset;
  vec3 col;
  if (ca > 0.001) {
    float a = 0.0045 * ca;
    col.r = texture(uTexture, clamp(duv + radial * a, 0.0, 1.0)).r;
    col.g = texture(uTexture, clamp(duv, 0.0, 1.0)).g;
    col.b = texture(uTexture, clamp(duv - radial * a, 0.0, 1.0)).b;
  } else {
    col = texture(uTexture, clamp(duv, 0.0, 1.0)).rgb;
  }

  // Glassy specular highlight on the launch ring.
  col += vec3(1.0) * ring * 0.14;

  // Brand tint riding the wavefront.
  float hue = atan(p.y, p.x) / 6.2832 + 0.5;
  vec3 grad = palette(hue + uTime * 0.02);
  col = mix(col, col + grad, clamp(band * 0.55, 0.0, 0.7));

  // ── Idle starfield: twinkling motes drift over the frozen frame and shy ──
  // away from the live cursor. Fades in as the launch sweep settles.
  vec2 st  = fragCoord / uResolution.y;        // aspect-square space -> round stars
  vec2 pst = uPointer  / uResolution.y;
  col += starField(st, pst, uTime) * idle;

  // ── Edge aura that persists after launch (breathing). ──
  float breath = 0.72 + 0.28 * sin(uTime * 1.2);
  float edge = smoothstep(0.5, 1.08, rEdge);
  col = mix(col, col + grad * 0.55, edge * 0.34 * breath);
  col *= 0.93;                               // slight global dim

  // ── Selection pop: crisp, undistorted, bright inside the marquee. ──
  bool hasSel = uSel.z > 0.5;
  vec2 selMin = uSel.xy;
  vec2 selMax = uSel.xy + uSel.zw;
  if (hasSel &&
      fragCoord.x >= selMin.x && fragCoord.x <= selMax.x &&
      fragCoord.y >= selMin.y && fragCoord.y <= selMax.y) {
    col = clamp(texture(uTexture, uv).rgb * 1.06, 0.0, 1.0);
  }

  fragColor = vec4(col, 1.0);
}
