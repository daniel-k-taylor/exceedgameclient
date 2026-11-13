shader_type canvas_item;

// Rounds the corners of a card face (a TextureRect / ColorRect stretched over the card).
// radius: the corner radius as a fraction of the card's width. aspect: height / width.
uniform float radius = 0.06;
uniform float aspect = 1.4;

void fragment() {
	vec4 c = COLOR;
	vec2 p = UV * vec2(1.0, aspect);
	vec2 half_size = vec2(0.5, 0.5 * aspect);
	vec2 d = abs(p - half_size) - (half_size - vec2(radius));
	float dist = length(max(d, vec2(0.0))) - radius;
	float aa = max(fwidth(dist), 0.0001);
	c.a *= clamp(0.5 - dist / aa, 0.0, 1.0);
	COLOR = c;
}
