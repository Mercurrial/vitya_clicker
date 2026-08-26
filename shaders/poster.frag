#version 460 core
#include <flutter/runtime_effect.glsl>

// Портрет Вити в стиле шелкографии / агитплаката.
//
// Фотография остаётся фотографией и потому выпадает из рисованного гаража.
// Здесь она сводится к нескольким тонам нашей палитры: получается печатное
// изображение, а не снимок, — и Витя перестаёт «выпадать» из мира игры.

uniform vec2 uSize;      // размер области отрисовки
uniform float uLevels;   // сколько тонов оставить (3–5)
uniform float uWarm;     // 0 = холодный дуотон, 1 = полностью медный
uniform float uPixels;   // ширина в «крупных пикселях»; 0 = без пикселизации
uniform sampler2D uTex;

out vec4 fragColor;

// Палитра гаража (см. lib/ui/theme/garage.dart)
const vec3 kInk    = vec3(0.055, 0.043, 0.031); // #0E0B08 тень
const vec3 kCopper = vec3(0.784, 0.475, 0.255); // #C87941 медь
const vec3 kAmber  = vec3(0.910, 0.639, 0.239); // #E8A33D янтарь
const vec3 kLight  = vec3(1.000, 0.898, 0.706); // #FFE5B4 свет лампы

void main() {
    vec2 uv = FlutterFragCoord().xy / uSize;

    // Пикселизация: сажаем координату на грубую сетку, беря цвет из центра
    // клетки. Вместе с постеризацией это и даёт спрайтовый вид — портрет
    // начинает жить в одном языке с нарисованным гаражом.
    if (uPixels > 1.0) {
        float aspect = uSize.y / max(uSize.x, 1.0);
        vec2 grid = vec2(uPixels, max(floor(uPixels * aspect), 1.0));
        uv = (floor(uv * grid) + 0.5) / grid;
    }

    vec4 src = texture(uTex, uv);

    // Яркость по восприятию, а не среднее по каналам.
    float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));

    // Небольшой подъём контраста — иначе после постеризации лицо «плывёт».
    lum = clamp((lum - 0.5) * 1.35 + 0.5, 0.0, 1.0);

    // Постеризация: непрерывный градиент превращается в ступени, как в печати.
    float levels = max(uLevels, 2.0);
    float q = floor(lum * levels) / (levels - 1.0);
    q = clamp(q, 0.0, 1.0);

    // Ступени раскладываем по палитре: тень -> медь -> янтарь -> свет.
    vec3 col;
    if (q < 0.34) {
        col = mix(kInk, kCopper, q / 0.34);
    } else if (q < 0.67) {
        col = mix(kCopper, kAmber, (q - 0.34) / 0.33);
    } else {
        col = mix(kAmber, kLight, (q - 0.67) / 0.33);
    }

    // uWarm позволяет приглушить эффект, не пересобирая шейдер.
    col = mix(vec3(q), col, clamp(uWarm, 0.0, 1.0));

    fragColor = vec4(col * src.a, src.a);
}
