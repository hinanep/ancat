shader_type canvas_item;

// 1. 颜色配置 (卡通渲染通常只需要明确的三个层次)
uniform vec4 color_surface : source_color = vec4(0.25, 0.71, 0.96, 1.0); // 浅水/水面
uniform vec4 color_depth : source_color = vec4(0.08, 0.35, 0.70, 1.0);   // 深水
uniform vec4 color_foam : source_color = vec4(1.0, 1.0, 1.0, 1.0);       // 浪沫纯白

// 2. 顶点波动控制
uniform float wave_amplitude = 12.0;
uniform float wave_frequency = 3.0;
uniform float wave_speed = 2.5;

// 3. 风格化参数
uniform float depth_threshold = 0.35; // 深水区开始的 UV 高度
uniform float foam_thickness = 0.04;  // 顶部白沫的基础厚度

void vertex() {
	float t = TIME * wave_speed;
	float x = UV.x * wave_frequency * 6.28318;

	// 抛弃单调的正弦波，使用伪 Gerstner 波形叠加
	// 特点：波峰更尖锐，波谷更平滑宽阔，水体动态更生动
	float wave = sin(x + t) + 0.5 * sin(2.0 * x - t * 1.2) + 0.25 * cos(3.0 * x + t * 0.8);

	// 同样利用 (1.0 - UV.y) 确保底部顶点锚定不乱动
	VERTEX.y += wave * wave_amplitude * (1.0 - UV.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// --- 1. 卡通硬边缘深度 (Cel-shaded Depth) ---
	// 加入轻微的 X 轴畸变，让深浅交界线具有流动感
	float depth_wobble = sin(uv.x * 15.0 + t * 2.0) * 0.03;
	// 使用 step 替代 mix/smoothstep，产生二次元特有的硬色块过渡
	float depth_mix = step(depth_threshold + depth_wobble, uv.y);
	vec4 base_color = mix(color_surface, color_depth, depth_mix);

	// --- 2. 动态顶部白沫边缘 (Dynamic Foam Line) ---
	float foam_wobble = sin(uv.x * 25.0 - t * 3.0) * 0.015 + cos(uv.x * 10.0 + t) * 0.01;
	float current_foam = foam_thickness + foam_wobble;
	float foam_mix = step(uv.y, current_foam);

	// --- 3. 风格化水波纹亮线 (Stylized Caustics) ---
	// 抛弃之前的散点噪点，使用被 X 轴正弦波高度扭曲的 Y 轴高频波，产生横向拉扯的亮线
	float caustic_wave = sin(uv.y * 60.0 + sin(uv.x * 12.0 + t * 2.0) * 3.0 - t * 4.0);
	// 截取波峰作为亮纹，并且仅在浅水区 (1.0 - depth_mix) 显示
	float caustics = step(0.85, caustic_wave) * (1.0 - depth_mix);

	// --- 4. 颜色合成 ---
	vec4 final_color = base_color;
	final_color.rgb += vec3(0.15) * caustics; // 浅水区叠加横向高光线
	final_color = mix(final_color, color_foam, foam_mix); // 最上层覆盖白沫

	COLOR = final_color;
}