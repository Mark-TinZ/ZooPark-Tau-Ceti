shader_type canvas_item;

// --- Группа: ЭЛТ Экран (Геометрия) ---
uniform float screen_curvature : hint_range(0.0, 0.5) = 0.1;    // Степень закругления (бочка)
uniform float screen_corner_radius : hint_range(0.0, 0.2) = 0.05; // Закругление углов монитора
uniform vec2 screen_size = vec2(1920.0, 1080.0);              // Разрешение твоей игры (входное)

// --- Группа: Сканирующие линии и Сдвиг ---
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.35; // Насыщенность сканлайнов
uniform float scanline_gap_size : hint_range(1.0, 4.0) = 2.0;   // Расстояние между сканлайнами (в пикселях)
uniform float roll_speed : hint_range(0.0, 5.0) = 0.16;         // Скорость "бегущей полосы"
uniform float roll_strength : hint_range(0.0, 0.2) = 0.02;     // Искажение от бегущей полосы

// --- Группа: Цвета и Маска ---
uniform float mask_strength : hint_range(0.0, 1.0) = 0.3;     // Яркость маски пикселей
uniform float chromatic_aberration : hint_range(0.0, 10.0) = 1.0; // Сдвиг цветов (РГБ)
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.6;    // Затемнение по краям
uniform float screen_brightness : hint_range(0.5, 2.0) = 1.2;  // Общая яркость экрана

// --- Технические переменные ---
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

// Вспомогательная функция для закругления углов (здесь return использовать можно, т.к. это кастомная функция)
float get_vignette(vec2 uv) {
    vec2 center = abs(uv - 0.5);
    float dist = length(max(center - 0.5 + screen_corner_radius, 0.0)) - screen_corner_radius;
    return smoothstep(-0.01, 0.0, -dist);
}

// Вспомогательная функция для маски пикселей
vec3 get_mask(vec2 pos) {
    vec3 mask = vec3(1.0);
    pos /= mask_strength * 2.0 + 1.0;
    mask.r = clamp(sin(pos.x * 2.0 * 3.14159) * 0.5 + 0.5, 0.0, 1.0);
    mask.g = clamp(sin((pos.x + 0.33) * 2.0 * 3.14159) * 0.5 + 0.5, 0.0, 1.0);
    mask.b = clamp(sin((pos.x + 0.67) * 2.0 * 3.14159) * 0.5 + 0.5, 0.0, 1.0);
    
    float vert = sin(pos.y * 2.0 * 3.14159) * 0.5 + 0.5;
    mask = mix(mask, vec3(vert), 0.5);
    return normalize(mask);
}

void fragment() {
    // 1. Координаты и Геометрия Экрана (Закругление)
    vec2 uv = SCREEN_UV;
    vec2 center_dist = uv - 0.5;
    float dist = length(center_dist);
    
    // "Бочка": Искажение координат
    vec2 uv_curved = 0.5 + center_dist * (1.0 + dist * dist * screen_curvature);
    
    // Проверка границ через if-else вместо return
    if (uv_curved.x < 0.0 || uv_curved.x > 1.0 || uv_curved.y < 0.0 || uv_curved.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 1.0);
    } else {
        // 2. Эффект обновления экрана (Роллинг)
        float roll = sin(uv_curved.y * 5.0 + TIME * roll_speed) * roll_strength;
        uv_curved.x += roll * (0.5 - abs(center_dist.y));

        // 3. Цвета и Хроматическая Аберрация
        float ca_offset = chromatic_aberration * 0.001;
        float r = texture(screen_texture, uv_curved + vec2(ca_offset, 0.0)).r;
        float g = texture(screen_texture, uv_curved).g;
        float b = texture(screen_texture, uv_curved - vec2(ca_offset, 0.0)).b;
        vec3 color = vec3(r, g, b);

        // 4. Сканлайны
        float scanline_y = uv_curved.y * screen_size.y;
        float scanline = sin(scanline_y * 3.14159 * 2.0 / scanline_gap_size);
        scanline = (scanline * 0.5 + 0.5) * scanline_strength + (1.0 - scanline_strength);
        
        // 5. Маска пикселей и Закругление углов (Финал)
        vec3 mask = get_mask(FRAGCOORD.xy);
        float vignette = get_vignette(uv_curved);
        vignette = mix(1.0, vignette, vignette_strength);

        // Смешиваем все эффекты
        color = color * scanline;
        color = color * mix(vec3(1.0), mask, mask_strength);
        color = color * screen_brightness;
        color = color * vignette;

        COLOR = vec4(color, 1.0);
    }
}