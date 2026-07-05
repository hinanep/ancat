extends Node

## GameWorld 开场控制器：天空主菜单态、相机滚动过渡与玩法冻结/解冻。

enum IntroState {
	SKY_MENU,
	SCROLLING,
	PLAYING,
}

const SKY_CAMERA_Y: float = -550.0
const GAME_CAMERA_Y: float = 0.0
const MENU_FADE_DURATION: float = 0.3
const HUD_FADE_DURATION: float = 0.3
const CAMERA_SCROLL_DURATION: float = 2.0

const _SELF_MANAGED_HUD_NAMES: Array[StringName] = [&'StormWarningUI', &'MarginContainer']

@onready var _camera: Camera2D = $"../WorldCamera"
@onready var _cabins: Node2D = $"../Cabins"
@onready var _water_surface: Node2D = $"../WaterSurface"
@onready var _game_hud: CanvasLayer = $"../CanvasLayer"
@onready var _storm_warning_ui = $"../CanvasLayer/StormWarningUI"
@onready var _main_menu: Control = $"../MenuLayer/MainMenu"
@onready var _storm_controller: Node = $"../StormController"
@onready var _customer_spawner: Node = $"../CustomerSpawner"
@onready var _stage_goal_manager: Node = $"../StageGoalManager"
@onready var _fishing_zone: Node = $"../FishingZone"
@onready var _test_player: CharacterBody2D = $"../Cabins/TestPlayer"

var _state: IntroState = IntroState.SKY_MENU
var _scroll_tween: Tween = null
var _hud_fade_tween: Tween = null


## 连接主菜单信号并进入天空菜单初始态。
## @return void
func _ready() -> void:
	_main_menu.start_pressed.connect(_on_start_pressed)
	enter_sky_menu(false)


## 是否处于可游玩态。
## @return bool
func is_playing() -> bool:
	return _state == IntroState.PLAYING


## 是否处于相机滚动过渡中。
## @return bool
func is_scrolling() -> bool:
	return _state == IntroState.SCROLLING


## 进入天空主菜单态：相机置高、冻结玩法、显示菜单。
## @param animate_menu 是否播放菜单淡入
## @return void
func enter_sky_menu(animate_menu: bool = true) -> void:
	_state = IntroState.SKY_MENU
	_kill_scroll_tween()
	AudioManager.stop_bgm()
	_camera.position.y = SKY_CAMERA_Y
	_set_gameplay_logic_frozen(true)
	_set_world_visuals_visible(false)
	_kill_hud_fade_tween()
	_set_hud_visible(false)
	_hide_storm_warning()
	_main_menu.set_menu_visible(true)
	if animate_menu:
		await _main_menu.fade_in(MENU_FADE_DURATION)
	else:
		_main_menu.modulate.a = 1.0


## 开始游戏：菜单淡出后相机下滚并进入玩法。
## @return void
func start_game() -> void:
	if _state != IntroState.SKY_MENU:
		return
	_state = IntroState.SCROLLING
	await _main_menu.fade_out(MENU_FADE_DURATION)
	_set_world_visuals_visible(true)
	await _scroll_camera_to(GAME_CAMERA_Y)
	await _enter_playing()


## 返回天空主菜单：冻结玩法后相机上滚并恢复菜单。
## @return void
func return_to_menu() -> void:
	if _state != IntroState.PLAYING:
		return
	_state = IntroState.SCROLLING
	AudioManager.stop_bgm()
	_set_gameplay_logic_frozen(true)
	_fade_out_hud(HUD_FADE_DURATION)
	_hide_storm_warning()
	await _scroll_camera_to(SKY_CAMERA_Y)
	await enter_sky_menu(true)


## 进入玩法态：淡入 HUD、解冻逻辑并播放 BGM。
## @return void
func _enter_playing() -> void:
	_state = IntroState.PLAYING
	_set_gameplay_logic_frozen(false)
	await _fade_in_hud(HUD_FADE_DURATION)
	AudioManager.play_bgm(ResPath.AUDIO.BGM_CALM)


## 设置世界层（船体/水面）可见性；滚动前显示以便随相机自然进入画面。
## @param world_visible 是否显示
## @return void
func _set_world_visuals_visible(world_visible: bool) -> void:
	_cabins.visible = world_visible
	_water_surface.visible = world_visible


## 冻结或解冻玩法逻辑，不影响世界层可见性。
## @param frozen 是否冻结
## @return void
func _set_gameplay_logic_frozen(frozen: bool) -> void:
	var active: bool = not frozen
	_storm_controller.set_process(active)
	_customer_spawner.set_process(active)
	_stage_goal_manager.set_process(active)
	_fishing_zone.set_process(active)
	_cabins.set_process(active)
	_test_player.set_process(active)
	_test_player.set_physics_process(active)


## 收集由 Intro 统一管理的 HUD 子节点（排除自管可见性的 UI）。
## @return Array[CanvasItem]
func _get_hud_items() -> Array[CanvasItem]:
	var items: Array[CanvasItem] = []
	for child in _game_hud.get_children():
		if child is CanvasItem and child.name not in _SELF_MANAGED_HUD_NAMES:
			items.append(child)
	return items


## 强制隐藏风暴预警 UI，避免被 HUD 淡入误显示。
## @return void
func _hide_storm_warning() -> void:
	_storm_warning_ui.hide_warning()


## 设置 HUD 子节点可见性并重置透明度。
## @param hud_visible 是否显示
## @return void
func _set_hud_visible(hud_visible: bool) -> void:
	for item in _get_hud_items():
		item.visible = hud_visible
		item.modulate.a = 1.0


## HUD 淡入。
## @param duration 动画时长（秒）
## @return void
func _fade_in_hud(duration: float) -> void:
	_kill_hud_fade_tween()
	var items: Array[CanvasItem] = _get_hud_items()
	for item in items:
		item.visible = true
		item.modulate.a = 0.0
	_hud_fade_tween = create_tween()
	_hud_fade_tween.set_parallel(true)
	for item in items:
		_hud_fade_tween.tween_property(item, 'modulate:a', 1.0, duration)
	await _hud_fade_tween.finished


## HUD 淡出并隐藏。
## @param duration 动画时长（秒）
## @return void
func _fade_out_hud(duration: float) -> void:
	_kill_hud_fade_tween()
	var items: Array[CanvasItem] = _get_hud_items()
	var any_visible: bool = false
	for item in items:
		if item.visible:
			any_visible = true
			break
	if not any_visible:
		return
	_hud_fade_tween = create_tween()
	_hud_fade_tween.set_parallel(true)
	for item in items:
		_hud_fade_tween.tween_property(item, 'modulate:a', 0.0, duration)
	await _hud_fade_tween.finished
	for item in items:
		item.visible = false
		item.modulate.a = 1.0


## 终止进行中的 HUD tween。
## @return void
func _kill_hud_fade_tween() -> void:
	if _hud_fade_tween != null and _hud_fade_tween.is_valid():
		_hud_fade_tween.kill()
	_hud_fade_tween = null


## 将相机 Y 轴 tween 到目标位置。
## @param target_y 目标 Y 坐标
## @return void
func _scroll_camera_to(target_y: float) -> void:
	_kill_scroll_tween()
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(
		_camera,
		'position:y',
		target_y,
		CAMERA_SCROLL_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await _scroll_tween.finished


## 终止进行中的相机 tween。
## @return void
func _kill_scroll_tween() -> void:
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	_scroll_tween = null


## 响应主菜单开始按钮。
## @return void
func _on_start_pressed() -> void:
	start_game()
