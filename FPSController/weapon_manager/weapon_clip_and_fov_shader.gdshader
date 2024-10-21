// NOTE: Shader automatically converted from Godot Engine 4.2.1.stable's StandardMaterial3D.

shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_disabled,diffuse_burley,specular_schlick_ggx;
uniform vec4 albedo : source_color = vec4(1., 1., 1., 1.);
uniform sampler2D texture_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform float point_size : hint_range(0,128) = 1.0;
uniform float roughness : hint_range(0,1) = 1.0;
uniform sampler2D texture_metallic : hint_default_white,filter_linear_mipmap,repeat_enable;
uniform vec4 metallic_texture_channel = vec4(0., 0., 0., 0.);
uniform sampler2D texture_roughness : hint_roughness_g,filter_linear_mipmap,repeat_enable;
uniform float specular = 0.5;
uniform float metallic = 1.0;
uniform sampler2D texture_normal : hint_roughness_normal,filter_linear_mipmap,repeat_enable;
uniform float normal_scale : hint_range(-16,16) = 1.0;
uniform vec3 uv1_scale = vec3(1., 1., 1.);
uniform vec3 uv1_offset = vec3(0., 0., 0.);
uniform vec3 uv2_scale = vec3(1., 1., 1.);
uniform vec3 uv2_offset = vec3(0., 0., 0.);

uniform float viewmodel_fov = 75.0f;

void vertex() {
	
	UV=UV*uv1_scale.xy+uv1_offset.xy;
	
	/* VIEW MODEL Z CLIP FIX CODE */
	if (viewmodel_fov > 0.0) {
		float onetanfov = 1.0f / tan(0.5f * (viewmodel_fov * PI / 180.0f));
		float aspect = VIEWPORT_SIZE.x / VIEWPORT_SIZE.y;
		// Optional: Modify projection matrix to change the FOV
		PROJECTION_MATRIX[1][1] = -onetanfov;
		PROJECTION_MATRIX[0][0] = onetanfov / aspect;
	}
	
	POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX.xyz, 1.0);
	// Mix vertex Z super close to clip plane, still maintaining some distance
	//POSITION.z = mix(POSITION.z, 0.0, 0.999); // Old version. Mix towards 0.0 (near z plane)
	// Above doesn't work for Godot 4.3 Z was reversed: https://godotengine.org/article/introducing-reverse-z/
	// Now we need to mix towards 1.0, but in clip space division by POSITION.w still hasn't happened.
	// So we mix z towards POSITION.w so that after perspective divsion, it will come out to 1.0 (near buffer since Z is reversed)
	POSITION.z = mix(POSITION.z, POSITION.w, 0.9); // Could be higher mix val like 0.999 but I found 0.9 prevented 99% clipping w/ less artifacts than 0.999.
	/* END VIEW MODEL Z CLIP FIX CODE */
}

// POSITION.xyz = POSITION.xyz / POSITION.w;

void fragment() {
	
	
	// https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#fragment-built-ins
	// in vec3 VERTEX
	// Vertex that comes from vertex function (default, in view space).
	// You can also do the depth mix in fragment shader, but I found it to case more artifacts.
	//vec4 clipSpace = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
	//vec3 ndc = clipSpace.xyz / clipSpace.w;
	//DEPTH = mix((ndc.z + 1.0) / 2.0, 1.0, 0.9);
	
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	float metallic_tex = dot(texture(texture_metallic,base_uv),metallic_texture_channel);
	METALLIC = metallic_tex * metallic;
	vec4 roughness_texture_channel = vec4(0.0,1.0,0.0,0.0);
	float roughness_tex = dot(texture(texture_roughness,base_uv),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	NORMAL_MAP = texture(texture_normal,base_uv).rgb;
	NORMAL_MAP_DEPTH = normal_scale;
}
