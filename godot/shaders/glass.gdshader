shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx, depth_draw_always;

// grime_tex: máscara do SubViewport (seção 5/6 do plano) — R = sujeira restante (0..1).
// fluid_tex: da CPU, R = água, G = sabão (grime_sim.gd fluid_bytes/window_pane.gd).
uniform sampler2D grime_tex : hint_default_black, filter_linear;
uniform sampler2D fluid_tex : hint_default_black, filter_linear;
uniform vec4 grime_color : source_color = vec4(0.36, 0.32, 0.22, 1.0);
uniform vec4 clean_tint : source_color = vec4(0.82, 0.9, 0.96, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.08;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float grime = texture(grime_tex, UV).r;
	vec2 fluid = texture(fluid_tex, UV).rg;
	float water = fluid.r;
	float soap = fluid.g;

	float n = hash(floor(UV * 512.0));
	float foam = smoothstep(0.15, 0.85, soap) * (0.6 + 0.4 * n);

	vec3 albedo = mix(clean_tint.rgb, grime_color.rgb, grime);
	albedo = mix(albedo, vec3(1.0), foam * 0.8);
	ALBEDO = albedo;

	// vidro limpo e molhado fica mais liso/especular; sujo fica fosco.
	ROUGHNESS = clamp(0.04 + grime * 0.55 - water * 0.3, 0.02, 0.9);
	METALLIC = 0.0;
	SPECULAR = clamp(0.5 + water * 0.5, 0.0, 1.0);

	// leve distorção do refresh de água, só pra dar vida — nada de refração real na v0.
	NORMAL_MAP = vec3(0.5 + (n - 0.5) * 0.04 * water, 0.5, 1.0);

	float dirty_alpha = base_alpha + grime * (1.0 - base_alpha) * 0.9;
	ALPHA = clamp(dirty_alpha + foam * 0.5, 0.0, 0.98);
}
