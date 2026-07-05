extends MovableCargo

## 可移动煎锅：放到炉子上后计时烹饪，支持盘子取出成品。
## @totalCookSec 煎制总时长（秒）
## @foodPlacementOffset 食材显示偏移
## @finishedFoodType 完成后展示的无盘料理类型
@export var totalCookSec: float = 20.0
@export var foodPlacementOffset: Vector2 = Vector2(0.0, -8.0)
@export var finishedFoodType: int = FoodConfig.FoodType.FRIED_FISH

var _foodNode: Node2D
var _isOnStove: bool = false
var _cookRemainingSec: float = 0.0
var _isCooked: bool = false
var _fryLoopActive: bool = false

@onready var _cookProgressBar: ProgressBar = $CookProgressBar
@onready var _collectPrompt: CookPlateCollectPrompt = get_node_or_null('CookPlateCollectPrompt') as CookPlateCollectPrompt


## 初始化煎锅状态。
func _ready() -> void:
	super._ready()
	add_to_group('FryingPan')
	_cookProgressBar.visible = false
	_cookProgressBar.min_value = 0.0
	_cookProgressBar.max_value = 1.0
	_cookProgressBar.value = 0.0


## 每帧推进烹饪计时。
## @param delta 帧间隔（秒）
func _process(delta: float) -> void:
	if _foodNode == null or not is_instance_valid(_foodNode):
		_foodNode = null
		_cookProgressBar.visible = false
		_hide_finished_result()
		_stop_fry_loop()
		return
	if not _isOnStove or _isCooked:
		if not _isOnStove:
			_stop_fry_loop()
		return
	_ensure_fry_loop_started()
	_cookRemainingSec = max(_cookRemainingSec - delta, 0.0)
	_update_progress_bar()
	if _cookRemainingSec <= 0.0:
		_isCooked = true
		_cookProgressBar.visible = false
		_stop_fry_loop()
		_on_cook_finished()
		return


## 设置是否在炉子上。
## @param value 是否在炉子上
func set_on_stove(value: bool) -> void:
	_isOnStove = value
	if value:
		enable_auto_move = false
		velocity = Vector2.ZERO
		_slide_speed = 0.0
	elif not _isCarried and not _isHooked:
		enable_auto_move = true
	if value and _foodNode != null and not _isCooked:
		_cookProgressBar.visible = true
		_update_progress_bar()
	elif not value:
		_cookProgressBar.visible = false
		_stop_fry_loop()


## 在炉上时冻结物理，避免与灶台碰撞弹开。
## @param delta 帧间隔（秒）
## @return void
func _physics_process(delta: float) -> void:
	if _isOnStove:
		velocity = Vector2.ZERO
		_slide_speed = 0.0
		return
	super._physics_process(delta)


## 是否有食材。
## @return bool
func has_food() -> bool:
	return _foodNode != null and is_instance_valid(_foodNode)


## 是否烹饪完成。
## @return bool
func is_cooked() -> bool:
	return _isCooked


## 是否正在炉上烹饪（有未熟食材且在炉上）。
## @return bool
func is_cooking() -> bool:
	return has_food() and not _isCooked and _isOnStove


## 是否可被新的锚勾取。
## @return bool
func can_be_hooked() -> bool:
	if is_cooking():
		return false
	return super.can_be_hooked()


## 放入食材并重置计时。
## @param food 食材节点
func add_food(food: Node2D) -> void:
	if _foodNode != null or food == null:
		return
	_foodNode = food
	_isCooked = false
	_cookRemainingSec = max(totalCookSec, 0.0)
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
	if _isOnStove:
		_cookProgressBar.visible = true
		_update_progress_bar()
	_hide_finished_result()


## 取出食材并重置状态。
## @return Node2D
func take_food() -> Node2D:
	if _foodNode == null:
		return null
	var food: Node2D = _foodNode
	_foodNode = null
	_isCooked = false
	_cookRemainingSec = 0.0
	_cookProgressBar.visible = false
	_stop_fry_loop()
	_hide_finished_result()
	return food


## 清空煎锅内部存储，不销毁煎锅本体。
## @return void
func clear_internal_storage() -> void:
	if _foodNode != null and is_instance_valid(_foodNode):
		_foodNode.queue_free()
	_foodNode = null
	_isCooked = false
	_cookRemainingSec = 0.0
	_cookProgressBar.visible = false
	_cookProgressBar.value = 0.0
	_stop_fry_loop()
	_hide_finished_result()


## 覆盖煎锅总烹饪时长，并按当前进度重映射剩余时间。
## @param newTotalSec 新总时长（秒）
## @return void
func apply_cook_total_sec(newTotalSec: float) -> void:
	var clampedTotalSec: float = max(newTotalSec, 0.0)
	var oldTotalSec: float = max(totalCookSec, 0.0)
	totalCookSec = clampedTotalSec
	if _foodNode != null and is_instance_valid(_foodNode) and not _isCooked:
		if oldTotalSec <= 0.0:
			_cookRemainingSec = clampedTotalSec
		else:
			var progress: float = 1.0 - (_cookRemainingSec / oldTotalSec)
			var safeProgress: float = clampf(progress, 0.0, 1.0)
			_cookRemainingSec = clampedTotalSec * (1.0 - safeProgress)
		if _isOnStove and _cookRemainingSec <= 0.0:
			_cookRemainingSec = 0.0
			_isCooked = true
			_cookProgressBar.visible = false
			_stop_fry_loop()
			_on_cook_finished()
			return
	_update_progress_bar()


## 更新进度条。
func _update_progress_bar() -> void:
	if totalCookSec <= 0.0:
		_cookProgressBar.value = 1.0
		return
	_cookProgressBar.value = 1.0 - (_cookRemainingSec / totalCookSec)


## 烹饪完成回调：切换食材熟食贴图。
## @return void
func _on_cook_finished() -> void:
	if _foodNode == null:
		return
	if _foodNode.has_method('set_cooked'):
		_foodNode.call('set_cooked', finishedFoodType)
	_foodNode.visible = false
	_show_finished_result()
	AudioManager.play_sfx(ResPath.AUDIO.PROGRESS_COMPLETE)
	_debug_log('fried food ready')


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


## 启动煎锅持续音效。
## @return void
func _ensure_fry_loop_started() -> void:
	if _fryLoopActive:
		return
	_fryLoopActive = true
	AudioManager.play_sfx_loop(_fry_loop_key(), ResPath.AUDIO.FRY_PAN)


## 停止煎锅持续音效。
## @return void
func _stop_fry_loop() -> void:
	if not _fryLoopActive:
		return
	_fryLoopActive = false
	AudioManager.stop_sfx_loop(_fry_loop_key())


## 返回煎锅循环音效 key。
## @return String
func _fry_loop_key() -> String:
	return 'fry_pan_%s' % get_instance_id()
