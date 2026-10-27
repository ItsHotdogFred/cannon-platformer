shader_type canvas_item;

uniform sampler2D mask_tex;
uniform float mask_cutoff = 0.5;

void fragment() {
	vec4 mask = texture(mask_tex, SCREEN_UV);
	if (mask.a >= mask_cutoff) {
		discard;
	}

	COLOR = texture(TEXTURE, UV) * COLOR;
}
