shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D normal_atlas : hint_normal, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D roughness_atlas : hint_default_black, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 coat_tint : source_color = vec4(1.0);
uniform vec2 atlas_offset = vec2(0.0);
uniform vec2 atlas_region_size = vec2(0.5);
uniform float pattern_scale = 2.35;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.72;

void fragment() {
	vec2 local_uv = fract(UV * pattern_scale);
	// Keep mip-filter samples inside the selected quadrant so neighbouring coats never bleed.
	vec2 padding = vec2(0.0025);
	vec2 atlas_uv = atlas_offset + padding + local_uv * (atlas_region_size - padding * 2.0);
	vec3 micro_albedo = texture(albedo_atlas, atlas_uv).rgb;
	ALBEDO = coat_tint.rgb * micro_albedo;
	NORMAL_MAP = texture(normal_atlas, atlas_uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = texture(roughness_atlas, atlas_uv).r;
	METALLIC = 0.0;
	SPECULAR = 0.22;
}
