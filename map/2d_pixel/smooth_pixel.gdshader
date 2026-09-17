shader_type canvas_item;

uniform vec2 vertex_offset;

void vertex() {
	VERTEX += vertex_offset;
}

void fragment() {
	vec2 uv_per_pixel = fwidth(UV);
	vec2 nearest_texel_corner = round(UV / TEXTURE_PIXEL_SIZE);
	vec2 nearest_texel_corner_uv = nearest_texel_corner * TEXTURE_PIXEL_SIZE;
	vec2 uv_dist = UV - nearest_texel_corner_uv;
	vec2 pixel_dist = uv_dist / uv_per_pixel;
	vec2 bilinear_weight = clamp(pixel_dist, -0.5, 0.5);
	vec2 sharp_uv = (nearest_texel_corner + bilinear_weight) * TEXTURE_PIXEL_SIZE;
	COLOR = texture(TEXTURE, sharp_uv);
}
