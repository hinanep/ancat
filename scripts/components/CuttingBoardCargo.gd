extends MovableCargo

## 可移动菜板：接收生鱼后进行处理计时，完成后可用盘子取出。
## @foodPlacementOffset 食材显示偏移
## @totalProcessSec 菜板处理总时长（秒）
## @finishedFoodType 完成后展示的无盘料理类型
@export var foodPlacementOffset: Vector2 = Vector2(0.0, -8.0)
@export var totalProcessSec: float = 5.0
@export var finishedFoodType: int = FoodConfig.FoodType.SASHIMI

var _foodNode: Node2D
var _isProcessed: bool = false
var _processRemainingSec: float = 0.0

@onready var _collectPrompt: CookPlateCollectPrompt = get_node_or_null('CookPlateCollectPrompt') as CookPlateCollectPrompt


## 初始化菜板。
func _ready() -> void:
	super._ready()
	add_to_group('CuttingBoard')


## 每帧推进菜板处理计时。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	if _foodNode == null or not is_instance_valid(_foodNode):
		_foodNode = null
		_isProcessed = false
		_processRemainingSec = 0.0
		_hide_finished_result()
		return
	if _isProcessed:
		return
	_processRemainingSec = max(_processRemainingSec - delta, 0.0)
	if _processRemainingSec <= 0.0:
		_isProcessed = true
		_on_process_finished()


## 是否有食材。
## @return bool
func has_food() -> bool:
	return _foodNode != null and is_instance_valid(_foodNode)


## 菜板结果是否已可取出（处理完成）。
## @return bool
func is_cooked() -> bool:
	return _isProcessed


## 是否正在处理食材（未完成前不可交互）。
## @return bool
func is_cooking() -> bool:
	return has_food() and not _isProcessed


## 是否可被新的锚勾取。
## @return bool
func can_be_hooked() -> bool:
	if is_cooking():
		return false
	return super.can_be_hooked()


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
	food.visible = false
	food.set_process(false)
	food.set_physics_process(false)
	if food is CollisionObject2D:
		(food as CollisionObject2D).collision_layer = 0
		(food as CollisionObject2D).collision_mask = 0
	if _isProcessed:
		_on_process_finished()
	else:
		_hide_finished_result()


## 取出结果并重置状态。
## @return Node2D
func take_food() -> Node2D:
	if _foodNode == null:
		return null
	var food: Node2D = _foodNode
	_foodNode = null
	_isProcessed = false
	_processRemainingSec = 0.0
	_hide_finished_result()
	return food


## 清空菜板内部存储，不销毁菜板本体。
## @return void
func clear_internal_storage() -> void:
	if _foodNode != null and is_instance_valid(_foodNode):
		_foodNode.queue_free()
	_foodNode = null
	_isProcessed = false
	_processRemainingSec = 0.0
	_hide_finished_result()


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
			_on_process_finished()


## 处理完成：隐藏生鱼并展示无盘成品与盘子浮标。
## @return void
func _on_process_finished() -> void:
	if _foodNode != null and is_instance_valid(_foodNode):
		if _foodNode.has_method('set_cooked'):
			_foodNode.call('set_cooked', finishedFoodType)
		_foodNode.visible = false
	_show_finished_result()
	AudioManager.play_sfx(ResPath.AUDIO.PROGRESS_COMPLETE)


## 显示成品无盘贴图与盘子收集浮标。
## @return void
func _show_finished_result() -> void:
	if _collectPrompt == null:
		return
	_collectPrompt.show_result(finishedFoodType)


## 隐藏成品展示。
## @return void
func _hide_finished_result() -> void:
	if _collectPrompt == null:
		return
	_collectPrompt.hide_result()
