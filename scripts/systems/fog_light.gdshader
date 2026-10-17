shader_type canvas_item;

uniform bool light_active = false;
uniform vec2 light_local = vec2(0.0);
uniform float light_radius = 15.0;
uniform float light_soft = 3.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (light_active) {
		float dist = distance(VERTEX.xy, light_local);
		float hole = smoothstep(light_radius, light_radius - light_soft, dist);
		tex.a *= 1.0 - hole;
	}
	COLOR = tex;
}
