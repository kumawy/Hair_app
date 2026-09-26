#include <flutter/runtime_effect.glsl>

// ImageFilter.shader supplies the size and sampler automatically.
uniform vec2 uSize;
uniform float uBarHeight;
uniform float uBarTop;
uniform sampler2D uBackdrop;

out vec4 fragColor;

void main() {
  vec2 position = FlutterFragCoord().xy;
  vec2 uv = position / uSize;
  #ifdef IMPELLER_TARGET_OPENGLES
    uv.y = 1.0 - uv.y;
  #endif
  float localY = position.y - uBarTop;
  float fade = 1.0 - smoothstep(0.3, 1.0, localY / uBarHeight);
  // Fade the filtered pixels themselves. SrcOver then blends them with the
  // untouched backdrop, without a ShaderMask save layer hiding that backdrop.
  fragColor = texture(uBackdrop, uv) * fade;
}
