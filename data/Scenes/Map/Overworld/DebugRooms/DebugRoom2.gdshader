shader_type canvas_item;

uniform vec2 shadow_offset = vec2(4.0, 4.0); // desplazamiento en píxeles
uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.4);
uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Convertir el offset de píxeles a UV
    vec2 offset_uv = UV - (shadow_offset / vec2(textureSize(TEXTURE, 0)));
    vec4 shadow_sample = texture(TEXTURE, offset_uv);

    if (tex_color.a > 0.0) {
        // dibuja el tile normal
        COLOR = tex_color;
    } else if (shadow_sample.a > 0.0) {
        // dibuja la sombra donde hay tile pero desplazado
        COLOR = shadow_color;
    } else {
        COLOR = vec4(0.0);
    }
}