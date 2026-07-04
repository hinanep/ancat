extends MovableCargo

## 可移动菜板：接收生鱼后进行处理计时，完成后可用盘子取出。
## @foodPlacementOffset 食材显示偏移
## @totalProcessSec 菜板处理总时长（秒）
@export var foodPlacementOffset: Vector2 = Vector2(0.0, -8.0)
@export var totalProcessSec: float = 5.0

var _foodNode: Node2D
var _isProcessed: bool = false
var _processRemainingSec: float = 0.0
@onready var _sashimiPromptBubble: Sprite2D = get_node_or_null('SashimiPromptBubble') as Sprite2D


## 初始化菜板。
func _ready() -> void:
	super._ready()
	add_to_group('CuttingBoard')
	_setup_sashimi_prompt_bubble()


## 每帧推进菜板处理计时。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	if _foodNode == null or not is_instance_valid(_foodNode):
		_foodNode = null
		_isProcessed = false
		_processRemainingSec = 0.0
		_set_sashimi_prompt_visible(false)
		return
	if _isProcessed:
		return
	_processRemainingSec = max(_processRemainingSec - delta, 0.0)
	if _processRemainingSec <= 0.0:
		_isProcessed = true
		_set_sashimi_prompt_visible(true)
		AudioManager.play_sfx(ResPath.AUDIO.PROGRESS_COMPLETE)


## 是否有食材。
## @return bool
func has_food() -> bool:
	return _foodNode != null and is_instance_valid(_foodNode)


## 菜板结果是否已可取出（处理完成）。
## @return bool
func is_cooked() -> bool:
	return _isProcessed


## 放入食材并开始处理计时。
## @param food 食材节点
func add_food(food: Node2D) -> void:
	if _foodNode != null or food == null:
		return
	_foodNode = food
	_isProcessed = false
	_processRemainingSec = max(totalProcessSec, 0.0)
	if _processRemainingSec <= 0.0:
		_isProcessed = true
	if food.has_method('drop_to_world'):
		food.call('drop_to_world')
	food.reparent(self)
	food.position = foodPlacementOffset
	food.set_process(false)
	food.set_physics_process(false)
	if food is CollisionObject2D:
		(food as CollisionObject2D).collision_layer = 0
		(food as CollisionObject2D).collision_mask = 0
	_set_sashimi_prompt_visible(_isProcessed)


## 取出结果并重置状态。
## @return Node2D
func take_food() -> Node2D:
	if _foodNode == null:
		return null
	var food: Node2D = _foodNode
	_foodNode = null
	_isProcessed = false
	_processRemainingSec = 0.0
	_set_sashimi_prompt_visible(false)
	return food


## 清空菜板内部存储，不销毁菜板本体。
## @return void
func clear_internal_storage() -> void:
	if _foodNode != null and is_instance_valid(_foodNode):
		_foodNode.queue_free()
	_foodNode = null
	_isProcessed = false
	_processRemainingSec = 0.0
	_set_sashimi_prompt_visible(false)


## 覆盖菜板总处理时长，并按当前进度重映射剩余时间。
## @param newTotalSec 新总时长（秒）
## @return void
func apply_process_total_sec(newTotalSec: float) -> void:
	var clampedTotalSec: float = max(newTotalSec, 0.0)
	var oldTotalSec: float = max(totalProcessSec, 0.0)
	totalProcessSec = clampedTotalSec
	if _foodNode != null and is_instance_valid(_foodNode) and not _isProcessed:
		if oldTotalSec <= 0.0:
			_processRemainingSec = clampedTotalSec
		else:
			var progress: float = 1.0 - (_processRemainingSec / oldTotalSec)
			var safeProgress: float = clampf(progress, 0.0, 1.0)
			_processRemainingSec = clampedTotalSec * (1.0 - safeProgress)
		if _processRemainingSec <= 0.0:
			_processRemainingSec = 0.0
			_isProcessed = true
			_set_sashimi_prompt_visible(true)


## 初始化生鱼片提示气泡贴图。
func _setup_sashimi_prompt_bubble() -> void:
	if _sashimiPromptBubble == null:
		return
	_sashimiPromptBubble.visible = false
	_sashimiPromptBubble.texture = FoodConfig.get_atlas_texture(FoodConfig.FoodType.SASHIMI)


## 控制“用盘子收集”提示气泡显隐。
## @param visible 是否显示
func _set_sashimi_prompt_visible(visible: bool) -> void:
	if _sashimiPromptBubble == null:
		return
	_sashimiPromptBubble.visible = visible
