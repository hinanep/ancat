## GameWorld 基础关卡脚本，处理关卡基础逻辑。
##
extends Node2D

@onready var _camera: Camera2D = $WorldCamera
@onready var _intro_controller: Node = $GameWorldIntroController

const _AGENT_DEBUG_LOG_PATH: String = 'C:/Users/nep/Desktop/mao/debug-dcfdb3.log'
const _AGENT_DEBUG_SESSION_ID: String = 'dcfdb3'

func _ready() -> void:
	EventBus.clear_deployed_anchor_cabin_paths()
	_camera.enabled = true
	EventBus.subscribe(_on_event)
	print_debug("GameWorld: level loaded")


func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)
	AudioManager.stop_bgm()


## 响应全局事件，在风暴阶段切换 BGM。
## @param event_type 事件类型
## @param _data 事件数据
## @return void
func _on_event(event_type: EventBus.EventType, _data: Dictionary) -> void:
	if not _intro_controller.is_playing():
		return
	match event_type:
		EventBus.EventType.STORM_STARTED:
			AudioManager.play_bgm(ResPath.AUDIO.BGM_STORM)
		EventBus.EventType.STORM_ENDED:
			AudioManager.play_bgm(ResPath.AUDIO.BGM_CALM)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _intro_controller.is_playing():
		_intro_controller.return_to_menu()
	#region agent log
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			_agent_debug_log_click(mouse_event.global_position)
	#endregion


#region agent log
## 记录左键点击时的 GUI 命中与 HUD 状态，用于排查输入被拦截。
## @param global_pos 屏幕坐标
## @return void
func _agent_debug_log_click(global_pos: Vector2) -> void:
	var hovered: Control = get_viewport().gui_get_hovered_control()
	var main_menu: Control = get_node_or_null('MenuLayer/MainMenu') as Control
	var shop_panel: Control = get_node_or_null('CanvasLayer/ShopPanelUI') as Control
	var intro_state: String = 'unknown'
	if _intro_controller.has_method('is_playing'):
		if _intro_controller.is_playing():
			intro_state = 'playing'
		elif _intro_controller.has_method('is_scrolling') and _intro_controller.is_scrolling():
			intro_state = 'scrolling'
		else:
			intro_state = 'sky_menu'
	var hovered_data: Dictionary = {}
	if hovered != null:
		hovered_data = {
			'name': hovered.name,
			'path': str(hovered.get_path()),
			'mouse_filter': hovered.mouse_filter,
			'visible': hovered.visible,
			'modulate_a': hovered.modulate.a,
			'global_rect': str(hovered.get_global_rect()),
		}
	var main_menu_data: Dictionary = {}
	if main_menu != null:
		main_menu_data = {
			'visible': main_menu.visible,
			'mouse_filter': main_menu.mouse_filter,
			'global_rect': str(main_menu.get_global_rect()),
		}
	var shop_data: Dictionary = {}
	if shop_panel != null:
		shop_data = {
			'visible': shop_panel.visible,
			'mouse_filter': shop_panel.mouse_filter,
			'global_rect': str(shop_panel.get_global_rect()),
		}
	var quadrant: String = 'other'
	if global_pos.x >= 960.0 and global_pos.y >= 540.0:
		quadrant = 'bottom_right'
	_agent_debug_write(
		'H2',
		'GameWorld.gd:_agent_debug_log_click',
		'mouse click probe',
		{
			'global_pos': [global_pos.x, global_pos.y],
			'quadrant': quadrant,
			'intro_state': intro_state,
			'hovered': hovered_data,
			'main_menu': main_menu_data,
			'shop_panel': shop_data,
			'blocks_anchor': hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE,
		}
	)


## 写入 NDJSON 调试日志。
## @param hypothesis_id 假设编号
## @param location 代码位置
## @param message 日志摘要
## @param data 附加数据
## @return void
func _agent_debug_write(hypothesis_id: String, location: String, message: String, data: Dictionary) -> void:
	var payload: Dictionary = {
		'sessionId': _AGENT_DEBUG_SESSION_ID,
		'hypothesisId': hypothesis_id,
		'location': location,
		'message': message,
		'data': data,
		'timestamp': Time.get_unix_time_from_system() * 1000,
	}
	var file: FileAccess = FileAccess.open(_AGENT_DEBUG_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(_AGENT_DEBUG_LOG_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))
	file.close()
#endregion
