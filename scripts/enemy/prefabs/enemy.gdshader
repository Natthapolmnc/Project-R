
shader_type spatial;

render_mode blend_mix, depth_prepass_alpha,
            cull_disabled, diffuse_lambert,
            specular_disabled;

uniform sampler2D sprite_texture : source_color, filter_nearest;
uniform float minimum_light : hint_range(0.0, 1.0) = 0.25;

void fragment() {
    vec4 tex = texture(sprite_texture, UV);

    ALBEDO = tex.rgb;
    ALPHA = tex.a;

    // Ensure the visible side faces the camera.
    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }
}

void light() {
    // Light the sprite from either direction.
    float intensity = abs(dot(NORMAL, LIGHT));

    intensity = max(intensity, minimum_light);

    DIFFUSE_LIGHT +=
        ALBEDO * LIGHT_COLOR * ATTENUATION * intensity;
}
