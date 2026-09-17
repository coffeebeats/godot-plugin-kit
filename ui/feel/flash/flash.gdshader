// Blends a sprite toward a flat color, for the hit flash driven by `FeelHitFlash2D`.
//
// Both uniforms are per-instance, so one shared material serves every sprite in the
// game and flashing one does not flash the rest. That keeps draw calls batched, where
// duplicating the material per sprite would not.
//
// A game whose sprites already have a shader of their own does not use this file. It
// adds the same two `instance uniform` lines and the one `mix` to its own shader, which
// is all `FeelHitFlash2D` needs to drive it.

shader_type canvas_item;

instance uniform vec4 flash_color : source_color = vec4(1.0);
instance uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(tex.rgb, flash_color.rgb, clamp(flash_amount, 0.0, 1.0)), tex.a);
}
