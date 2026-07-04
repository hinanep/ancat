extends Area2D

## 钓鱼区参数：鱼生成、游动边界与风暴禁钓状态。
## 鱼预制体。
@export var fishScene: PackedScene = preload('res://scenes/props/FishEntity.tscn')
## 目标鱼数量。
@export var targetFishCount: int = 6
## 补鱼间隔（秒）。
@export var spawnIntervalSec: float = 1.0
## 调试日志开关。
@export var debugFishingZoneLog: bool = false

var _spawnTimer: float = 0.0
var _stormActive: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _shapeNode: CollisionShape2D = $CollisionShape2D


## 初始化：加入分组并订阅风暴事件。
## @return void
func _ready() -> void:
	_rng.randomize()
	add_to_group('FishingZone')
	_spawnTimer = max(spawnIntervalSec, 0.1)
	EventBus.subscribe(_on_event)
	_debug_log('ready')


## 退出时取消订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 每帧维护鱼数量。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	if _stormActive:
		return
	_spawnTimer -= delta
	if _spawnTimer > 0.0:
		return
	_spawnTimer = max(spawnIntervalSec, 0.1)
	_refill_fish()


## 当前是否可钓鱼（供外部查询）。
## @return bool
func can_fish() -> bool:
	return not _stormActive


## 补足目标鱼数量（仅统计游动态鱼）。
## @return void
func _refill_fish() -> void:
	if fishScene == null:
		return
	var aliveSwimmingCount: int = 0
	for node in get_tree().get_nodes_in_group('Fish'):
		if node != null and node.has_method('is_swimming_fish'):
			if bool(node.call('is_swimming_fish')):
				aliveSwimmingCount += 1
	if aliveSwimmingCount >= max(targetFishCount, 0):
		return
	_spawn_one_fish()


## 生成一条鱼并设置游动边界。
## @return void
func _spawn_one_fish() -> void:
	var fishNode: Node = fishScene.instantiate()
	if fishNode == null:
		return
	get_tree().current_scene.add_child(fishNode)
	if fishNode is Node2D:
		(fishNode as Node2D).global_position = _random_point_in_zone()
	if fishNode.has_method('set_swim_bounds'):
		fishNode.call('set_swim_bounds', _zone_rect_global())
	if fishNode.has_method('start_spawn_fade_in'):
		fishNode.call('start_spawn_fade_in')


## 读取钓鱼区矩形边界（全局）。
## @return Rect2
func _zone_rect_global() -> Rect2:
	var rectShape: RectangleShape2D = _shapeNode.shape as RectangleShape2D
	if rectShape == null:
		return Rect2(global_position - Vector2(120.0, 80.0), Vector2(240.0, 160.0))
	var half: Vector2 = rectShape.size * 0.5 * global_scale
	return Rect2(global_position - half, half * 2.0)


## 在钓鱼区随机采样一个点。
## @return Vector2
func _random_point_in_zone() -> Vector2:
	var rect: Rect2 = _zone_rect_global()
	return Vector2(
		_rng.randf_range(rect.position.x, rect.end.x),
		_rng.randf_range(rect.position.y, rect.end.y)
	)


## 接收风暴事件并更新禁钓状态。
## @param eventType 事件类型
## @param data 事件数据
## @return void
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	var _unusedData: Dictionary = data
	match eventType:
		EventBus.EventType.STORM_STARTED:
			_stormActive = true
			_clear_all_fish()
		EventBus.EventType.STORM_ENDED:
			_stormActive = false
			_spawnTimer = max(spawnIntervalSec, 0.1)
		_:
			pass


## 输出调试日志。
## @param message 日志文本
## @return void
func _debug_log(message: String) -> void:
	if not debugFishingZoneLog:
		return
	print('[FishingZone] %s' % message)


## 清空当前所有鱼实体（风暴期间鱼消失）。
## @return void
func _clear_all_fish() -> void:
	for node in get_tree().get_nodes_in_group('Fish'):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method('is_swimming_fish') and bool(node.call('is_swimming_fish')):
			(node as Node).queue_free()
