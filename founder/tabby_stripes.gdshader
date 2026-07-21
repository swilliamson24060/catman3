shader_type spatial;

// Draws tabby stripes -- bands that span the body's full left-right width
// and alternate front-to-back, like rings wrapping around it -- using the
// fragment's true 3D object-space position instead of texture UV. This
// model's UV mapping mirrors left and right body geometry onto the exact
// same texture pixels (confirmed via mesh dump analysis: every fur/eye UV
// column has ~0 average 3D X, meaning it's shared by both sides), so no
// texture-space stripe pattern can ever vary left-to-right. Object-space
// position doesn't have that problem -- it varies correctly and
// continuously across every face -- so we use it directly here.

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform sampler2D fur_mask_tex : filter_nearest;
uniform vec4 body_color : source_color;
uniform vec4 secondary_color : source_color;
uniform float stripe_width = 0.15;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec4 tex_color = texture(albedo_tex, UV);
	float fur_mask = texture(fur_mask_tex, UV).r;

	if (fur_mask > 0.5) {
		// Band on object-space Z (front-back) so each stripe spans the
		// body's full left-right width, like rings wrapping around it --
		// not bands running lengthwise along the spine.
		float band = floor(obj_pos.z / stripe_width);
		float side = mod(band, 2.0);
		ALBEDO = side < 1.0 ? body_color.rgb : secondary_color.rgb;
	} else {
		ALBEDO = tex_color.rgb;
	}
}
