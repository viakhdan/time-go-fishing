shader_type canvas_item;
// Fills a sprite's shape with one flat colour, for undiscovered fish (DESIGN.md §9.4).

uniform vec4 fill_color : source_color = vec4(0.071, 0.078, 0.075, 1.0);

void fragment() {
	COLOR = vec4(fill_color.rgb, texture(TEXTURE, UV).a * fill_color.a);
}
