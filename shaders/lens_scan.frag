#version 460 core
#include <flutter/runtime_effect.glsl>

// AI Lens launch — "Glass sweep": a refractive band front radiates from the
// screen centre across the frozen frame (lens refraction + chromatic aberration
// + specular ring + brand tint), then settles to a gently breathing coloured
// edge aura. A dragged selection stays crisp, undistorted and slightly brighter.
uniform vec2 uResolution;   // logical px
uniform float uTime;        // seconds, continuous (drives tint drift + aura breath)
uniform float uOpenT;       // 0..1 launch progress
uniform vec4 uSel;          // x, y, w, h (logical px); w <= 0 => no selection
uniform vec2 uCursor;       // cursor position in logical px (top-left origin)
uniform sampler2D uTexture; // the frozen frame

out vec4 fragColor;

// Brand gradient palette (purple -> pink -> blue -> cyan).
const vec3 C1 = vec3(0.486, 0.227, 0.929);
const vec3 C2 = vec3(0.925, 0.286, 0.600);
const vec3 C3 = vec3(0.231, 0.510, 0.965);
const vec3 C4 = vec3(0.133, 0.827, 0.933);

vec3 palette(float t) {
  t = fract(t);
  if (t < 0.333) return mix(C1, C2, t / 0.333);
  if (t < 0.666) return mix(C2, C3, (t - 0.333) / 0.333);
  return mix(C3, C4, (t - 0.666) / 0.334);
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

  // Glassy specular highlight on the ring.
  col += vec3(1.0) * ring * 0.14;

  // Brand tint riding the wavefront.
  float hue = atan(p.y, p.x) / 6.2832 + 0.5;
  vec3 grad = palette(hue + uTime * 0.02);
  col = mix(col, col + grad, clamp(band * 0.55, 0.0, 0.7));

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
