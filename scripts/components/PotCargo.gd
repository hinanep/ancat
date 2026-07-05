extends MovableCargo

## 锅：可携带可交互的烹饪容器，管理食材状态与烹饪计时。
## @totalCookSec 总烹饪时长（秒）
## @foodPlacementOffset 食材在锅上的显示偏移
@export var totalCookSec: float = 30.0
@export var foodPlacementOffset: Vector2 = Vector2(0.0, -10.0)

var _foodNode: Node2D
var _isOnStove: bool = false
var _cookRemainingSec: float = 0.0
var _isCooked: bool = false

@onready var _cookProgressBar: ProgressBar = $CookProgressBar


## 初始化：加入 Pot 分组，隐藏进度条。
func _ready() -> void:
	super._ready()
	add_to_group('Pot')
	_cookProgressBar.visible = false
	_cookProgressBar.min_value = 0.0
	_cookProgressBar.max_value = 1.0
	_cookProgressBar.value = 0.0


## 每帧推进烹饪计时，在炉上且有未熟食材时倒计时。
## @param delta 帧间隔（秒）
func _process(delta: float) -> void:
	if _foodNode == null or not is_instance_valid(_foodNode):
		_foodNode = null
		_cookProgressBar.visible = false
		_stop_stove_loop()
		return
	if not _isOnStove or _isCooked:
		return
	_cookRemainingSec = max(_cookRemainingSec - delta, 0.0)
	_update_progress_bar()
	if _cookRemainingSec <= 0.0:
		_isCooked = true
		_cookProgressBar.visible = false
		_on_cook_finished()


## 设置是否在锅炉上，控制烹饪计时与进度条显示。
## @param value 是否在锅炉上
func set_on_stove(value: bool) -> void:
	_isOnStove = value
	if value and _foodNode != null and not _isCooked:
		_cookProgressBar.visible = true
		_update_progress_bar()
	elif not value:
		_cookProgressBar.visible = false


## 锅中是否有食材。
## @return bool
func has_food() -> bool:
	return _foodNode != null and is_instance_valid(_foodNode)


## 食材是否已熟。
## @return bool
func is_cooked() -> bool:
	return _isCooked


## 放入食材到锅中，重置烹饪计时。
## 调用 drop_to_world 重置食材携带状态后 reparent 到锅下并停止物理。
## @param food 食材节点
func add_food(food: Node2D) -> void:
	if _foodNode != null:
		return
	if food == null:
		return
	_foodNode = food
	_isCooked = false
	_cookRemainingSec = max(totalCookSec, 0.0)
	if food.has_method('drop_to_world'):
		food.call('drop_to_world')
	food.reparent(self)
	food.position = foodPlacementOffset
	food.set_process(false)
	food.set_physics_process(false)
	if food is CollisionObject2D:
		(food as CollisionObject2D).collision_layer = 0
		(food as CollisionObject2D).collision_mask = 0
	if _isOnStove:
		_cookProgressBar.visible = true
		_update_progress_bar()


## 取出锅中食材并重置烹饪状态。
## @return Node2D 食材节点，无食材时返回 null
func take_food() -> Node2D:
	if _foodNode == null:
		return null
	var food: Node2D = _foodNode
	_foodNode = null
	_isCooked = false
	_cookRemainingSec = 0.0
	_cookProgressBar.visible = false
	return food


## 清空锅内部存储，不销毁锅本体。
## @return void
func clear_internal_storage() -> void:
	if _foodNode != null and is_instance_valid(_foodNode):
		_foodNode.queue_free()
	_foodNode = null
	_isCooked = false
	_cookRemainingSec = 0.0
	_cookProgressBar.visible = false
	_cookProgressBar.value = 0.0


## 覆盖锅总烹饪时长，并按当前进度重映射剩余时间。
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
			_on_cook_finished()
			return
	_update_progress_bar()


## 更新进度条数值。
func _update_progress_bar() -> void:
	if totalCookSec <= 0.0:
		_cookProgressBar.value = 1.0
		return
	_cookProgressBar.value = 1.0 - (_cookRemainingSec / totalCookSec)


## 烹饪完成回调：调用食材的 set_cooked 方法切换熟食状态。
func _on_cook_finished() -> void:
	if _foodNode == null:
		return
	if _foodNode.has_method('set_cooked'):
		_foodNode.call('set_cooked')
	#region agent log
	_debug_cook_preview_log(
		'H3',
		'PotCargo.gd:_on_cook_finished',
		'pot cook finished',
		{
			'servedFoodTypeIfPlated': FoodConfig.FoodType.BOILED_FISH,
			'foodName': _foodNode.name if _foodNode != null else ''
		}
	)
	#endregion
	AudioManager.play_sfx(ResPath.AUDIO.PROGRESS_COMPLETE)
	_stop_stove_loop()
	_debug_log('food cooked!')


## 停止当前锅实例对应的炉子循环音效。
## @return void
func _stop_stove_loop() -> void:
	AudioManager.stop_sfx_loop('stove_%s' % get_instance_id())


func _debug_cook_preview_log(hypothesisId: String, location: String, message: String, data: Dictionary) -> void:
	var log_path: String = 'C:/Users/nep/Desktop/mao/debug-d44187.log'
	var payload: Dictionary = {
		'sessionId': 'd44187',
		'hypothesisId': hypothesisId,
		'location': location,
		'message': message,
		'data': data,
		'timestamp': Time.get_unix_time_from_system() * 1000.0
	}
	var file: FileAccess = FileAccess.open(log_path, FileAccess.READ_WRITE if FileAccess.file_exists(log_path) else FileAccess.WRITE_READ)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(payload))
