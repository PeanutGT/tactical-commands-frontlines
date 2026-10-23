shader_type canvas_item;
// Ground for a StylePack with terrain textures. `cells` (also the sprite's
// texture, which sets its size) holds one texel per cell: R = Terrain.Type,
// G = height level, B = 1 where a bridge deck runs left-right. Ground
// pictures come from `ground`, one layer each.

uniform sampler2D cells : filter_nearest;
uniform sampler2DArray ground : filter_linear_mipmap, repeat_enable;
uniform vec2 map_size;
// Cells covered by one repeat of a ground picture.
uniform float tile_cells = 8.0;
// Texture layer and colour multiplier per Terrain.Type.
uniform int layer_of[11];
uniform vec4 tint_of[11];
// Brightness per height level 0..3.
uniform float height_shade[4];
uniform vec4 contour_color : source_color;
// Contour line width, in cells.
uniform float contour_width = 0.12;
// Width of the soft border between two terrain types, in cells.
uniform float blend_width = 0.3;
// How far borders wander from the cell grid, in cells.
uniform float edge_wobble = 0.22;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 cell_data(ivec2 c) {
	c = clamp(c, ivec2(0), ivec2(map_size) - 1);
	return texelFetch(cells, c, 0).rgb * 255.0;
}

// Ground colour of terrain `t` at `p` (cells). Two samples at different
// scales are mixed by a slow noise so the repeat is hard to spot.
vec3 ground_color(int t, vec2 p, bool across) {
	vec2 uv = p / tile_cells;
	float layer = float(layer_of[t]);
	vec3 a;
	if (t == 9) {
		// Bridge decks are painted running up-down.
		a = texture(ground, vec3(across ? uv.yx : uv, layer)).rgb;
	} else {
		a = texture(ground, vec3(uv, layer)).rgb;
		vec3 b = texture(ground, vec3(uv * 0.71 + vec2(0.37, 0.59), layer)).rgb;
		a = mix(a, b, smoothstep(0.35, 0.65, value_noise(p * 0.09)));
	}
	return a * tint_of[t].rgb;
}

void fragment() {
	vec2 p = UV * map_size;
	// Borders between terrain types: blend the four nearest cells, with the
	// sample point nudged by noise so edges are not ruler-straight.
	vec2 q = p + (vec2(value_noise(p * 1.7), value_noise(p * 1.7 + 19.3)) - 0.5) * edge_wobble * 2.0;
	vec2 g = q - 0.5;
	ivec2 base = ivec2(floor(g));
	vec2 f = smoothstep(vec2(0.5 - blend_width * 0.5), vec2(0.5 + blend_width * 0.5), fract(g));
	vec3 c00 = cell_data(base);
	vec3 c10 = cell_data(base + ivec2(1, 0));
	vec3 c01 = cell_data(base + ivec2(0, 1));
	vec3 c11 = cell_data(base + ivec2(1, 1));
	int t00 = int(round(c00.r));
	int t10 = int(round(c10.r));
	int t01 = int(round(c01.r));
	int t11 = int(round(c11.r));
	vec4 w = vec4((1.0 - f.x) * (1.0 - f.y), f.x * (1.0 - f.y), (1.0 - f.x) * f.y, f.x * f.y);
	vec3 col;
	if (t00 == t10 && t00 == t01 && t00 == t11) {
		col = ground_color(t00, p, cell_data(ivec2(floor(p))).b > 0.5);
	} else {
		col = ground_color(t00, p, c00.b > 0.5) * w.x + ground_color(t10, p, c10.b > 0.5) * w.y
			+ ground_color(t01, p, c01.b > 0.5) * w.z + ground_color(t11, p, c11.b > 0.5) * w.w;
	}
	// Height shading, smoothed the same way.
	float shade = height_shade[int(round(c00.g))] * w.x + height_shade[int(round(c10.g))] * w.y
		+ height_shade[int(round(c01.g))] * w.z + height_shade[int(round(c11.g))] * w.w;
	col *= shade;

	// Contour lines on cell edges where the height level changes.
	ivec2 c = ivec2(floor(p));
	vec2 l = fract(p);
	float e = cell_data(c).g;
	float d = 1.0;
	if (cell_data(c + ivec2(-1, 0)).g != e) d = min(d, l.x);
	if (cell_data(c + ivec2(1, 0)).g != e) d = min(d, 1.0 - l.x);
	if (cell_data(c + ivec2(0, -1)).g != e) d = min(d, l.y);
	if (cell_data(c + ivec2(0, 1)).g != e) d = min(d, 1.0 - l.y);
	float aa = fwidth(p.x);
	float line = 1.0 - smoothstep(contour_width * 0.5 - aa, contour_width * 0.5 + aa, d);
	col = mix(col, contour_color.rgb, line * contour_color.a);
	COLOR = vec4(col, 1.0);
}
