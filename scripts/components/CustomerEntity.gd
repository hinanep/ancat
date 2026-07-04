extends Node2D

## 顾客状态：渐入、寻座、就座等待、离场。
enum CustomerState {
	FADE_IN,
	SEEKING,
	WAITING_FOR_SEAT,
	WALK_TO_SEAT,
	SEATED,
	FADE_OUT
}

## 顾客表现与流程参数。
## @walkSpeed 行走速度（像素/秒）
## @waitTimeoutSec 等待超时（秒）
## @fadeInSec 渐入时长（秒）
## @spawnPauseSec 渐入完成后原地停顿时长（秒）
## @fadeOutSec 渐出时长（秒）
@export var walkSpeed: float = 80.0
@export var waitTimeoutSec: float = 60.0
@export var fadeInSec: float = 0.5
@export var spawnPauseSec: float = 2.0
@export var fadeOutSec: float = 0.5
@export var debugCustomerLog: bool = true

var _state: CustomerState = CustomerState.FADE_IN
var _demands: Array[int] = []
var _isVip: bool = false
var _elapsedInState: float = 0.0
var _waitElapsed: float = 0.0
var _targetTable: Node
var _isLeavingBySatisfied: bool = false
var _totalDemandPrice: int = 0

@onready var _demandIcons: Node2D = $DemandIcons


## 初始化顾客需求与VIP标记。
## @param demands 需求列表
## @param isVip 是否VIP
## @return void
func initialize_customer(demands: Array[int], isVip: bool) -> void:
	_demands = demands.duplicate()
	_isVip = isVip
	_totalDemandPrice = 0
	for demandType in _demands:
		_totalDemandPrice += FoodConfig.get_price(demandType)
	_refresh_demand_icons()


## 每帧推进顾客状态机。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	_elapsedInState += delta
	match _state:
		CustomerState.FADE_IN:
			_process_fade_in()
		CustomerState.SEEKING:
			_process_seeking()
		CustomerState.WAITING_FOR_SEAT:
			_process_waiting_for_seat(delta)
		CustomerState.WALK_TO_SEAT:
			_process_walk_to_seat(delta)
		CustomerState.SEATED:
			_process_seated(delta)
		CustomerState.FADE_OUT:
			_process_fade_out()


## 尝试交付一道菜品给顾客。
## @param foodType 菜品类型
## @return bool
func try_serve_food(foodType: int) -> bool:
	if _state != CustomerState.SEATED:
		return false
	if _demands.is_empty():
		return false
	var index: int = _demands.find(foodType)
	if index == -1:
		return false
	_demands.remove_at(index)
	_refresh_demand_icons()
	if _demands.is_empty():
		_on_all_demands_satisfied()
	return true


## 获取当前是否已满足全部需求。
## @return bool
func is_satisfied() -> bool:
	return _demands.is_empty()


## 获取未满足需求。
## @return Array[int]
func get_unmet_demands() -> Array[int]:
	return _demands.duplicate()


## 返回顾客是否VIP。
## @return bool
func is_vip_customer() -> bool:
	return _isVip


## 渐入状态处理。
func _process_fade_in() -> void:
	var duration: float = max(fadeInSec, 0.01)
	var alpha: float = clampf(_elapsedInState / duration, 0.0, 1.0)
	modulate.a = alpha
	if alpha >= 1.0 and _elapsedInState >= duration + max(spawnPauseSec, 0.0):
		_enter_state(CustomerState.SEEKING)


## 寻座状态处理。
func _process_seeking() -> void:
	var table: Node = _find_free_table_in_current_cabin()
	if table != null:
		_targetTable = table
		_enter_state(CustomerState.WALK_TO_SEAT)
		return
	_enter_state(CustomerState.WAITING_FOR_SEAT)


## 等位状态处理。
## @param delta 帧间隔（秒）
func _process_waiting_for_seat(delta: float) -> void:
	_waitElapsed += delta
	if _waitElapsed >= max(waitTimeoutSec, 1.0):
		_start_leave(false)
		return
	var table: Node = _find_free_table_in_current_cabin()
	if table == null:
		return
	_targetTable = table
	_enter_state(CustomerState.WALK_TO_SEAT)


## 走向座位状态处理。
## @param delta 帧间隔（秒）
func _process_walk_to_seat(delta: float) -> void:
	if _targetTable == null or not is_instance_valid(_targetTable):
		_enter_state(CustomerState.SEEKING)
		return
	if not _targetTable.has_method('get_seat_global_position'):
		_enter_state(CustomerState.SEEKING)
		return
	var targetPos: Vector2 = _targetTable.call('get_seat_global_position')
	var speed: float = max(walkSpeed, 1.0)
	global_position = global_position.move_toward(targetPos, speed * delta)
	if global_position.distance_to(targetPos) > 2.0:
		return
	if _targetTable.has_method('seat_customer'):
		var seated: bool = bool(_targetTable.call('seat_customer', self))
		if seated:
			_enter_state(CustomerState.SEATED)
			return
	_enter_state(CustomerState.SEEKING)


## 就座状态处理。
## @param delta 帧间隔（秒）
func _process_seated(delta: float) -> void:
	if _targetTable == null or not is_instance_valid(_targetTable):
		_enter_state(CustomerState.SEEKING)
		return
	_waitElapsed += delta
	if _waitElapsed >= max(waitTimeoutSec, 1.0):
		_start_leave(false)


## 渐出状态处理。
func _process_fade_out() -> void:
	var duration: float = max(fadeOutSec, 0.01)
	var alpha: float = clampf(1.0 - (_elapsedInState / duration), 0.0, 1.0)
	modulate.a = alpha
	if alpha > 0.0:
		return
	queue_free()


## 切换状态并重置计时器。
## @param nextState 下一状态
func _enter_state(nextState: CustomerState) -> void:
	_state = nextState
	_elapsedInState = 0.0
	if nextState == CustomerState.WAITING_FOR_SEAT or nextState == CustomerState.SEATED:
		_waitElapsed = 0.0


## 找同舱室内空闲桌子。
## @return Node
func _find_free_table_in_current_cabin() -> Node:
	var parentNode: Node = get_parent()
	if parentNode == null:
		return null
	var bestTable: Node
	var bestDist: float = INF
	for table in get_tree().get_nodes_in_group('DiningTable'):
		if table == null or not is_instance_valid(table):
			continue
		var tableCabin: Node = null
		if table.get_parent() == parentNode:
			tableCabin = parentNode
		elif table.get_parent() != null and table.get_parent().get_parent() == parentNode:
			tableCabin = parentNode
		if tableCabin == null:
			continue
		if not table.has_method('is_seat_free') or not bool(table.call('is_seat_free')):
			continue
		var dist: float = (table as Node2D).global_position.distance_to(global_position) if table is Node2D else 0.0
		if dist < bestDist:
			bestDist = dist
			bestTable = table
	return bestTable


## 刷新头顶需求图标。
func _refresh_demand_icons() -> void:
	if _demandIcons == null:
		return
	for child in _demandIcons.get_children():
		child.queue_free()
	var total: int = _demands.size()
	for i in range(total):
		var demandType: int = _demands[i]
		var icon := Sprite2D.new()
		icon.texture = FoodConfig.get_atlas_texture(demandType)
		var centered: float = (float(total - 1) * 0.5)
		icon.position = Vector2((float(i) - centered) * 18.0, 0.0)
		_demandIcons.add_child(icon)


## 顾客需求全部满足时结算并离场。
func _on_all_demands_satisfied() -> void:
	var payAmount: int = _totalDemandPrice
	if payAmount <= 0:
		payAmount = 1
	if _isVip:
		payAmount *= 2
	if GameState.has_method('add_gold'):
		GameState.call('add_gold', payAmount)
	EventBus.emit(EventBus.EventType.CUSTOMER_SERVED, {'pay': payAmount, 'vip': _isVip})
	_start_leave(true)


## 开始离场流程并释放座位。
## @param bySatisfied 是否因满足需求离场
func _start_leave(bySatisfied: bool) -> void:
	_isLeavingBySatisfied = bySatisfied
	if _targetTable != null and is_instance_valid(_targetTable) and _targetTable.has_method('unseat_customer'):
		_targetTable.call('unseat_customer', self)
	_targetTable = null
	_enter_state(CustomerState.FADE_OUT)
	EventBus.emit(EventBus.EventType.CUSTOMER_LEFT, {'satisfied': _isLeavingBySatisfied})
