shader_type canvas_item;
render_mode blend_mix;

uniform int smoke_OCTAVES = 4;
uniform float smoke_speed = 0.5;
uniform float smoke_variation_speed = 1.0;
uniform float smoke_variation_mul = 2.0;
uniform float smoke_treshold = 0.1;
uniform float smoke_scale = 160.0;
uniform vec4  smoke_color: source_color = vec4(0.4, 0.44, 0.5, 1.0);

uniform float noise_power = 0.0004;
uniform float noise_tiling = 200.0;
uniform float noise_speed = 0.15;

uniform mat4 global_transform;
varying vec2 global_position;

uniform bool toggle_visible_smoke = false;
uniform float thresh = 0.5;

void vertex() {
	global_position = (global_transform * vec4(VERTEX, 1.0, 1.0)).xy;
}

vec3 mod2893(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod2894(vec4 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
     return mod2894(((x*34.0)+1.0)*x);
}

vec4 taylorInvSqrt(vec4 r)
{
  return 1.79284291400159 - 0.85373472095314 * r;
}

float snoise(vec3 v)
  { 
  const vec2  C = vec2(1.0/6.0, 1.0/3.0) ;
  const vec4  D = vec4(0.0, 0.5, 1.0, 2.0);

// First corner
  vec3 i  = floor(v + dot(v, C.yyy) );
  vec3 x0 =   v - i + dot(i, C.xxx) ;

// Other corners
  vec3 g = step(x0.yzx, x0.xyz);
  vec3 l = 1.0 - g;
  vec3 i1 = min( g.xyz, l.zxy );
  vec3 i2 = max( g.xyz, l.zxy );

  //   x0 = x0 - 0.0 + 0.0 * C.xxx;
  //   x1 = x0 - i1  + 1.0 * C.xxx;
  //   x2 = x0 - i2  + 2.0 * C.xxx;
  //   x3 = x0 - 1.0 + 3.0 * C.xxx;
  vec3 x1 = x0 - i1 + C.xxx;
  vec3 x2 = x0 - i2 + C.yyy; // 2.0*C.x = 1/3 = C.y
  vec3 x3 = x0 - D.yyy;      // -1.0+3.0*C.x = -0.5 = -D.y

// Permutations
  i = mod2893(i); 
  vec4 p = permute( permute( permute( 
             i.z + vec4(0.0, i1.z, i2.z, 1.0 ))
           + i.y + vec4(0.0, i1.y, i2.y, 1.0 )) 
           + i.x + vec4(0.0, i1.x, i2.x, 1.0 ));

// Gradients: 7x7 points over a square, mapped onto an octahedron.
// The ring size 17*17 = 289 is close to a multiple of 49 (49*6 = 294)
  float n_ = 0.142857142857; // 1.0/7.0
  vec3  ns = n_ * D.wyz - D.xzx;

  vec4 j = p - 49.0 * floor(p * ns.z * ns.z);  //  mod(p,7*7)

  vec4 x_ = floor(j * ns.z);
  vec4 y_ = floor(j - 7.0 * x_ );    // mod(j,N)

  vec4 x = x_ *ns.x + ns.yyyy;
  vec4 y = y_ *ns.x + ns.yyyy;
  vec4 h = 1.0 - abs(x) - abs(y);

  vec4 b0 = vec4( x.xy, y.xy );
  vec4 b1 = vec4( x.zw, y.zw );

  //vec4 s0 = vec4(lessThan(b0,0.0))*2.0 - 1.0;
  //vec4 s1 = vec4(lessThan(b1,0.0))*2.0 - 1.0;
  vec4 s0 = floor(b0)*2.0 + 1.0;
  vec4 s1 = floor(b1)*2.0 + 1.0;
  vec4 sh = -step(h, vec4(0.0));

  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy ;
  vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww ;

  vec3 p0 = vec3(a0.xy,h.x);
  vec3 p1 = vec3(a0.zw,h.y);
  vec3 p2 = vec3(a1.xy,h.z);
  vec3 p3 = vec3(a1.zw,h.w);

//Normalise gradients
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3)));
  p0 *= norm.x;
  p1 *= norm.y;
  p2 *= norm.z;
  p3 *= norm.w;

// Mix final noise value
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0);
  m = m * m;
  return 42.0 * dot( m*m, vec4( dot(p0,x0), dot(p1,x1), 
                                dot(p2,x2), dot(p3,x3) ) );
  }


float rand(vec2 coord){
	return fract(sin(dot(coord, vec2(12.9898, 78.233)))* 43758.5453123);
}

float noise(vec2 coord){
	vec2 i = floor(coord);
	vec2 f = fract(coord);

    // 4 corners of a rectangle surrounding our point
	float a = rand(i);
	float b = rand(i + vec2(1.0, 0.0));
	float c = rand(i + vec2(0.0, 1.0));
	float d = rand(i + vec2(1.0, 1.0));

	vec2 cubic = f * f * (3.0 - 2.0 * f);

	return mix(a, b, cubic.x) + (c - a) * cubic.y * (1.0 - cubic.x) + (d - b) * cubic.x * cubic.y;
}

float fbm(vec2 coord){
	float value = 0.0;
	float scale = 0.5;

	for(int i = 0; i < smoke_OCTAVES; i++){
		value += noise(coord) * scale;
		coord *= 2.0;
		scale *= 0.5;
	}
	return value;
}

void fragment()
{
//	vec2 scaled_coord = (UV + global_position) * smoke_scale;
//
//	float motion_fbm = fbm(scaled_coord + vec2(TIME * 0.08, TIME * 0.06) * smoke_speed); // used for distorting the smoke_fbm texture
//	float smoke_fbm = fbm(scaled_coord + vec2(-TIME * 0.02, TIME * -0.04) * smoke_variation_speed + motion_fbm * smoke_variation_mul);
//
//	smoke_fbm = clamp(smoke_fbm - smoke_treshold, 0.0, 1.0) / (1.0 - smoke_treshold);
//	if (smoke_fbm < 0.1) {
//		smoke_fbm *= smoke_fbm / 0.1;
//	}
//
//	float smoke_fbm_sqrt = sqrt(smoke_fbm);
//	COLOR.rgb = vec3(clamp( smoke_fbm_sqrt * 0.5, 0.0, 1.0 )) * smoke_color.rgb * smoke_fbm_sqrt;

	COLOR.rgb = vec3(0.0);
	float distx = snoise(vec3(TIME * noise_speed, UV * noise_tiling));
	float disty = snoise(vec3(TIME * noise_speed, UV * noise_tiling + 130.0));
//	vec2 dostortion = vec2( distx-0.5 , disty-0.5 ) * smoke_fbm * noise_power;
	vec2 dostortion = vec2( distx-0.5 , disty-0.5 ) * noise_power;
	
	vec4 fragColor = texture(TEXTURE, vec2(UV.x, 1.0 - UV.y) + dostortion);
	fragColor = clamp( fragColor * 1.1 - 0.1, 0.0, 1.0);
//	float maxfragColor = max(max(fragColor.r,fragColor.g),fragColor.b);

	
//	COLOR.a = 1.0 - max((maxfragColor - smoke_fbm * thresh * float(toggle_visible_smoke)), 0.0);
	COLOR.a = 1.0 - (fragColor.r);




//	COLOR.rgb = vec3(smoke_fbm);
//	COLOR.a = 1.0;
}
