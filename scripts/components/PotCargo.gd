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
	_debug_log('food cooked!')
