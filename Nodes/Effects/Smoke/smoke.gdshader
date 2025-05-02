shader_type particles;
render_mode keep_data;
uniform vec3 direction;
uniform float spread;
uniform float flatness;
uniform float initial_linear_velocity;
uniform float initial_angle;
uniform float angular_velocity;
uniform float orbit_velocity;
uniform float linear_accel;
uniform float radial_accel;
uniform float tangent_accel;
uniform float damping;
uniform float scale;
uniform float hue_variation;
uniform float anim_speed;
uniform float anim_offset;
uniform float initial_linear_velocity_random;
uniform float initial_angle_random;
uniform float angular_velocity_random;
uniform float orbit_velocity_random;
uniform float linear_accel_random;
uniform float radial_accel_random;
uniform float tangent_accel_random;
uniform float damping_random;
uniform float scale_random;
uniform float hue_variation_random;
uniform float anim_speed_random;
uniform float anim_offset_random;
uniform float lifetime_randomness;
uniform vec4 color_value : source_color;
uniform int trail_divisor;
uniform vec3 gravity;
uniform sampler2D color_ramp;
uniform sampler2D scale_texture;

uniform sampler2D emission_texture_points : hint_default_black;
uniform int emission_texture_point_count;
uniform sampler2D emission_texture_color : hint_default_white;
uniform int spawn = 0;
uniform int spawn2 = 0;
uniform vec2 spawn_velocity = vec2(0.0,0.0);


uniform float fake_lifetime = 5.0;

float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0)
	s = 305420679;
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0)
		s += 2147483647;
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

float rand_from_seed_m1_p1(inout uint seed) {
	return rand_from_seed(seed) * 2.0 - 1.0;
}

uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

void process() {
	uint base_number = NUMBER / uint(trail_divisor);
	uint alt_seed = hash(base_number + uint(1) + RANDOM_SEED);
	float angle_rand = rand_from_seed(alt_seed);
	float scale_rand = rand_from_seed(alt_seed);
	float hue_rot_rand = rand_from_seed(alt_seed);
	float anim_offset_rand = rand_from_seed(alt_seed);
	float pi = 3.14159;
	float degree_to_rad = pi / 180.0;

	bool restart = false;
	float tv = 0.0;
	vec3 pos = TRANSFORM[3].xyz;

	int point = int(INDEX - uint(spawn2));
	ivec2 emission_tex_size = textureSize(emission_texture_points, 0);
	ivec2 emission_tex_ofs = ivec2(point % emission_tex_size.x, point / emission_tex_size.x);

	if (INDEX >= uint(spawn)) {
		VELOCITY = vec3(0);
		TRANSFORM[3].xy = vec2(-1000.0, -1000.0);
	}

	if (int(pos.z) == 0 && INDEX >= uint(spawn2) && INDEX < uint(spawn)) {
		TRANSFORM[3].z = 1.0;
		restart=true;
	}

	if (RESTART || restart) {
		TRANSFORM[3].xy = texelFetch(emission_texture_points, emission_tex_ofs, 0).xy;
		COLOR = texelFetch(emission_texture_color, emission_tex_ofs, 0);
		float tex_linear_velocity = 0.0;
		float tex_angle = 0.0;
		float tex_anim_offset = 0.0;
		float spread_rad = spread * degree_to_rad;
		{
			float angle1_rad = rand_from_seed_m1_p1(alt_seed) * spread_rad;
			angle1_rad += direction.x != 0.0 ? atan(direction.y, direction.x) : sign(direction.y) * (pi / 2.0);
			vec3 rot = vec3(cos(angle1_rad), sin(angle1_rad), 0.0);
			VELOCITY = rot * initial_linear_velocity * (-0.5 + rand_from_seed(alt_seed));
		}
		float base_angle = (initial_angle + tex_angle) * mix(1.0, angle_rand, initial_angle_random);
		CUSTOM.x = base_angle * degree_to_rad;
		CUSTOM.y = 0.0;
		CUSTOM.z = (anim_offset + tex_anim_offset) * mix(1.0, anim_offset_rand, anim_offset_random);
		VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
		VELOCITY.xy += spawn_velocity*rand_from_seed(alt_seed);
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
		VELOCITY.z = 0.0;
		float alphascale=1.0/max(COLOR.a,0.01);
		CUSTOM.w=alphascale;
		// TRANSFORM[3].z = 0.0;
	} else {
		CUSTOM.y += DELTA / fake_lifetime;
		tv = CUSTOM.y;
		float tex_linear_velocity = 0.0;
		float tex_orbit_velocity = 0.0;
		float tex_angular_velocity = 0.0;
		float tex_linear_accel = 0.0;
		float tex_radial_accel = 0.0;
		float tex_tangent_accel = 0.0;
		float tex_damping = 0.0;
		float tex_angle = 0.0;
		float tex_anim_speed = 0.0;
		float tex_anim_offset = 0.0;
		vec3 force = gravity;
		// apply linear acceleration
		force += length(VELOCITY) > 0.0 ? normalize(VELOCITY) * (linear_accel + tex_linear_accel) * mix(1.0, rand_from_seed(alt_seed), linear_accel_random) : vec3(0.0);
		// apply radial acceleration
		vec3 org = EMISSION_TRANSFORM[3].xyz;
		vec3 diff = pos - org;
		force += length(diff) > 0.0 ? normalize(diff) * (radial_accel + tex_radial_accel) * mix(1.0, rand_from_seed(alt_seed), radial_accel_random) : vec3(0.0);
		// apply tangential acceleration;
		force += length(diff.yx) > 0.0 ? vec3(normalize(diff.yx * vec2(-1.0, 1.0)), 0.0) * ((tangent_accel + tex_tangent_accel) * mix(1.0, rand_from_seed(alt_seed), tangent_accel_random)) : vec3(0.0);
		// apply attractor forces
		VELOCITY += force * DELTA;
		// orbit velocity
		float orbit_amount = (orbit_velocity + tex_orbit_velocity) * mix(1.0, rand_from_seed(alt_seed), orbit_velocity_random);
		if (orbit_amount != 0.0) {
		     float ang = orbit_amount * DELTA * pi * 2.0;
		     mat2 rot = mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang)));
		     TRANSFORM[3].xy -= diff.xy;
		     TRANSFORM[3].xy += rot * diff.xy;
		}
		if (damping + tex_damping > 0.0) {
			float v = length(VELOCITY);
			float damp = (damping + tex_damping) * mix(1.0, rand_from_seed(alt_seed), damping_random);
			v -= damp * DELTA;
			if (v < 0.0) {
				VELOCITY = vec3(0.0);
			} else {
				VELOCITY = normalize(VELOCITY) * v;
			}
		}
		float base_angle = (initial_angle + tex_angle) * mix(1.0, angle_rand, initial_angle_random);
		base_angle += CUSTOM.y * fake_lifetime * (angular_velocity + tex_angular_velocity) * mix(1.0, rand_from_seed(alt_seed) * 2.0 - 1.0, angular_velocity_random);
		CUSTOM.x = base_angle * degree_to_rad;
		CUSTOM.z = (anim_offset + tex_anim_offset) * mix(1.0, anim_offset_rand, anim_offset_random) + CUSTOM.y * (anim_speed + tex_anim_speed) * mix(1.0, rand_from_seed(alt_seed), anim_speed_random);
	}
	float tex_scale = textureLod(scale_texture, vec2(tv, 0.0), 0.0).r;
	COLOR.a = textureLod(color_ramp, vec2(tv, 0.0), 0.0).a;

	TRANSFORM[0] = vec4(cos(CUSTOM.x), -sin(CUSTOM.x), 0.0, 0.0);
	TRANSFORM[1] = vec4(sin(CUSTOM.x), cos(CUSTOM.x), 0.0, 0.0);
	TRANSFORM[2] = vec4(0.0, 0.0, 1.0, 0.0);
	float base_scale = clamp(CUSTOM.w,1.0,5.0) * tex_scale * mix(scale, 1.0, scale_random * scale_rand);
	if (base_scale < 0.000001) {
		base_scale = 0.000001;
	}
	TRANSFORM[0].xyz *= base_scale;
	TRANSFORM[1].xyz *= base_scale;
	TRANSFORM[2].xyz *= base_scale;
	VELOCITY.z = 0.0;
}

