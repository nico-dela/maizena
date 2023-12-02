shader_type canvas_item;

uniform float u_amount = 0.1;

float get_noise(vec2 uv) {
    return fract(sin(dot(uv ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    float n = 1.0 * get_noise(UV + vec2(TIME, 0.0)) - 1.0;
    COLOR = texture(TEXTURE, UV) + n * u_amount;
}

// Pixelated version
//void fragment() {
//    vec2 k = 4.0 / TEXTURE_PIXEL_SIZE;
//    vec2 pixel_coords = floor(k * UV) + k * vec2(TIME);
//    float n = 2.0 * get_noise(pixel_coords) - 1.0;
//    COLOR = texture(TEXTURE, UV) + n * u_amount;
//}
