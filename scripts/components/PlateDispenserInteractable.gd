extends InteractableBase

## 盘子机：冷却完成后可直接给玩家一个空盘，支持顶部进度条显示。
## @plateScene 盘子预制体
## @cooldownSec 产出冷却时长（秒）
## @maxPlateCount 全局盘子上限
## @dispensedPlateScale 产出盘子缩放
@export var plateScene: PackedScene = ResPath.PROP_SCENES.PLATE_CARGO
@export var cooldownSec: float = 10.0
@export var maxPlateCount: int = 8
@export var dispensedPlateScale: Vector2 = Vector2(2.3, 2.3)

var _cooldownRemaining: float = 0.0

@onready var _cooldownProgress: ProgressBar = get_parent().get_node_or_null('CooldownProgress') as ProgressBar


## 初始化并加入可交互组。
func _ready() -> void:
	super._ready()
	_setup_progress_ui()


## 每帧更新冷却进度显示。
## @param delta 帧间隔（秒）
func _process(delta: float) -> void:
	if _cooldownRemaining > 0.0:
		_cooldownRemaining = max(_cooldownRemaining - delta, 0.0)
	_update_progress_ui()


## 判定当前能否产出盘子。
## @param player 玩家节点
## @param item 携带物
## @param anchorController 锚控制器
## @return bool
func _can_interact_now(player: Node, item: Node, anchorController: Node) -> bool:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	if anchorController == null:
		#region agent log
		_plate_debug_emit('H-C', 'PlateDispenserInteractable.gd:_can_interact_now', 'deny: no anchorController', {})
		#endregion
		return false
	if _cooldownRemaining > 0.0:
		#region agent log
		_plate_debug_emit('H-C', 'PlateDispenserInteractable.gd:_can_interact_now', 'deny: cooldown', {'cooldownRemaining': _cooldownRemaining})
		#endregion
		return false
	var plateCount: int = _current_plate_count()
	if plateCount >= max(maxPlateCount, 1):
		#region agent log
		_plate_debug_emit('H-C', 'PlateDispenserInteractable.gd:_can_interact_now', 'deny: plate cap', {'plateCount': plateCount, 'maxPlateCount': maxPlateCount})
		#endregion
		return false
	if not anchorController.has_method('try_add_carried_cargo'):
		#region agent log
		_plate_debug_emit('H-C', 'PlateDispenserInteractable.gd:_can_interact_now', 'deny: no try_add_carried_cargo', {})
		#endregion
		return false
	return true


## 仅允许“空手”从机器取盘（有携带物时不响应）。
## @param item 候选物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	return item == null


## 生成空盘并直接放入玩家手中。
## @param player 玩家节点
## @param item 携带物
## @param anchorController 锚控制器
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	if plateScene == null:
		return
	var plateNode: Node = plateScene.instantiate()
	if plateNode == null:
		return
	get_tree().current_scene.add_child(plateNode)
	if plateNode is Node2D and player is Node2D:
		(plateNode as Node2D).global_position = (player as Node2D).global_position
		(plateNode as Node2D).scale = dispensedPlateScale
	var added: bool = bool(anchorController.call('try_add_carried_cargo', plateNode))
	if not added:
		plateNode.queue_free()
		return
	if plateNode.has_method('clear_food'):
		plateNode.call('clear_food')
	_cooldownRemaining = max(cooldownSec, 0.0)
	_update_progress_ui()
	_log_interact('dispense plate success')


## 空手交互不消耗携带物。
## @param item 携带物
## @return bool
func _consume_carried_on_item_valid(item: Node) -> bool:
	var _unusedItem: Node = item
	return false


## 初始化进度条显示参数。
func _setup_progress_ui() -> void:
	if _cooldownProgress == null:
		return
	_cooldownProgress.min_value = 0.0
	_cooldownProgress.max_value = max(cooldownSec, 0.01)
	_cooldownProgress.show_percentage = false
	_update_progress_ui()


## 刷新进度条值（满值表示可领取）。
func _update_progress_ui() -> void:
	if _cooldownProgress == null:
		return
	var total: float = max(cooldownSec, 0.01)
	var progressed: float = total - clampf(_cooldownRemaining, 0.0, total)
	_cooldownProgress.value = progressed


## 统计当前全场盘子数量（通过 Plate 分组）。
## @return int
func _current_plate_count() -> int:
	return get_tree().get_nodes_in_group('Plate').size()


## 写入调试 NDJSON 日志。
## @param hypothesisId 假设编号
## @param location 位置
## @param message 消息
## @param data 数据
## @return void
func _plate_debug_emit(hypothesisId: String, location: String, message: String, data: Dictionary) -> void:
	var payload: Dictionary = {
		'sessionId': '9bf2e4',
		'runId': 'right-click-slide-pre',
		'hypothesisId': hypothesisId,
		'location': location,
		'message': message,
		'data': data,
		'timestamp': Time.get_unix_time_from_system() * 1000.0
	}
	var logPath: String = 'C:/Users/nep/Desktop/mao/debug-9bf2e4.log'
	var file: FileAccess = null
	if FileAccess.file_exists(logPath):
		file = FileAccess.open(logPath, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(logPath, FileAccess.WRITE_READ)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))
