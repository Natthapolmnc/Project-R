
shader_type sky;

// ==========================================
// SKY COLORS
// ==========================================

uniform vec4 sky_top : source_color = vec4(0.32, 0.47, 0.58, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.58, 0.68, 0.68, 1.0);

uniform float gradient_height : hint_range(0.1, 2.0) = 0.85;
uniform float color_steps : hint_range(2.0, 32.0) = 12.0;


// ==========================================
// CLOUD COLORS
// ==========================================

uniform vec4 cloud_light : source_color = vec4(0.94, 0.94, 0.90, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.73, 0.78, 0.77, 1.0);


// ==========================================
// CLOUD SHAPE
// ==========================================

uniform float cloud_scale : hint_range(0.5, 20.0) = 3.5;

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.48;

uniform float cloud_detail : hint_range(0.0, 1.0) = 0.30;

uniform float pixel_resolution : hint_range(16.0, 512.0) = 90.0;

uniform float cloud_speed : hint_range(0.0, 1.0) = 0.015;


// ==========================================
// HORIZON CONTROL
// ==========================================

uniform float cloud_horizon_start : hint_range(-1.0, 1.0) = 0.12;

uniform float cloud_horizon_end : hint_range(-1.0, 1.0) = 0.38;

uniform float horizon_fade_steps : hint_range(1.0, 16.0) = 5.0;


// ==========================================
// NOISE FUNCTIONS
// ==========================================

float hash(vec2 p) {
    return fract(
        sin(dot(p, vec2(127.1, 311.7)))
        * 43758.5453
    );
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(
        mix(a, b, u.x),
        mix(c, d, u.x),
        u.y
    );
}

float fbm(vec2 p) {
    float value = 0.0;

    value += noise(p) * 0.60;
    value += noise(p * 2.0) * 0.30;
    value += noise(p * 4.0) * 0.10;

    return value;
}


// ==========================================
// MAIN SKY SHADER
// ==========================================

void sky() {

    vec3 dir = normalize(EYEDIR);

    // --------------------------------------
    // SKY GRADIENT
    // --------------------------------------

    float gradient = smoothstep(
        -0.15,
        gradient_height,
        dir.y
    );

    gradient = floor(
        gradient * color_steps
    ) / color_steps;

    vec3 sky_color = mix(
        sky_horizon.rgb,
        sky_top.rgb,
        gradient
    );


    // --------------------------------------
    // SPHERICAL CLOUD COORDINATES
    // --------------------------------------

    // Horizontal angle wraps around the sky.
    float longitude = atan(dir.z, dir.x);

    float latitude = asin(clamp(dir.y, -1.0, 1.0));

    vec2 uv = vec2(
        longitude / 6.2831853,
        latitude / 3.14159265
    );


    // --------------------------------------
    // PIXELATED CLOUD SAMPLING
    // --------------------------------------

    // Quantize cloud coordinates into blocks.
    vec2 pixel_uv = floor(
        uv * pixel_resolution
    ) / pixel_resolution;

    vec2 cloud_uv = pixel_uv * cloud_scale;

    cloud_uv.x += TIME * cloud_speed;


    // --------------------------------------
    // ORGANIC CLOUD SHAPES
    // --------------------------------------

    float large_shape = fbm(cloud_uv * 3.0);

    float small_detail = noise(
        cloud_uv * 11.0
    );

    float cloud_noise = mix(
        large_shape,
        small_detail,
        cloud_detail
    );

    float cloud_mask = step(
        cloud_coverage,
        cloud_noise
    );


    // --------------------------------------
    // STYLIZED CLOUD SHADING
    // --------------------------------------

    float shading_noise = noise(
        cloud_uv * 5.0 + vec2(4.7, 9.2)
    );

    float shadow_mask = step(
        0.52,
        shading_noise
    );

    vec3 cloud_color = mix(
        cloud_shadow.rgb,
        cloud_light.rgb,
        shadow_mask
    );


    // --------------------------------------
    // PIXELATED HORIZON FADE
    // --------------------------------------

    float horizon_fade = smoothstep(
        cloud_horizon_start,
        cloud_horizon_end,
        dir.y
    );

    horizon_fade = floor(
        horizon_fade * horizon_fade_steps
    ) / horizon_fade_steps;

    cloud_mask *= horizon_fade;


    // --------------------------------------
    // FINAL COLOR
    // --------------------------------------

    COLOR = mix(
        sky_color,
        cloud_color,
        cloud_mask
    );
}
