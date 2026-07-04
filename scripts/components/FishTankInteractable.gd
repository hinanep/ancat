extends InteractableBase

## 鱼缸交互参数：入缸容量、倾斜滑出与滑出落点配置。
## 盘子分组名（用于从鱼缸取鱼装盘）。
@export var plateGroupName: StringName = 'Plate'
## 鱼缸最大存储数量。
@export var maxFishCount: int = 3
## 触发滑出的船体倾斜阈值（度）。
@export var spillTiltThresholdDeg: float = 8.0
## 风暴期间溢出检测间隔（秒）。
@export var spillCheckIntervalSec: float = 1.0
## 单次溢出事件后冷却（秒）。
@export var spillEventCooldownSec: float = 15.0
## 滑出落点基础偏移。
@export var spillDropOffset: Vector2 = Vector2(0.0, 22.0)
## 滑出落点随机 X 振幅。
@export var spillDropRandomX: float = 18.0
## 鱼缸内游动范围尺寸。
@export var tankSwimRectSize: Vector2 = Vector2(44.0, 16.0)
## 鱼缸内游动范围偏移。
@export var tankSwimRectOffset: Vector2 = Vector2(0.0, 2.0)
## 第一段动画时长：鱼先运动到上沿角点（秒）。
@export var spillToEdgeDurationSec: float = 0.5
## 第二段动画时长：鱼从上沿角点飞出（秒）。
@export var spillOutDurationSec: float = 0.5
## 溢出动画抛物线高度（像素）。
@export var spillAnimArcHeight: float = 22.0
## 风暴溢出最小概率（每秒）。
@export var stormSpillMinChancePerSec: float = 0.15
## 风暴溢出最大概率（每秒）。
@export var stormSpillMaxChancePerSec: float = 0.75
## 达到该倾斜角时使用最大概率（度）。
@export var stormSpillMaxTiltDeg: float = 30.0

var _storedFish: Array[Node] = []
var _spillCheckTimer: float = 0.0
var _spillEventCooldown: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lastPlateTakeAccepted: bool = false
var _stormSpillEnabled: bool = false
var _stormDirection: float = 0.0


## 初始化随机数。
## @return void
func _ready() -> void:
	super._ready()
	_rng.randomize()
	EventBus.subscribe(_on_event)


## 每帧处理倾斜滑出。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	_spillCheckTimer = max(_spillCheckTimer - delta, 0.0)
	_spillEventCooldown = max(_spillEventCooldown - delta, 0.0)
	_cleanup_stored_fish()
	if _storedFish.is_empty():
		return
	if not _stormSpillEnabled:
		return
	if _spillEventCooldown > 0.0:
		return
	if _spillCheckTimer > 0.0:
		return
	_spillCheckTimer = max(spillCheckIntervalSec, 0.05)
	var absTiltDeg: float = absf(rad_to_deg(global_rotation))
	if absTiltDeg < max(spillTiltThresholdDeg, 0.0):
		return
	var spillChance: float = _spill_chance_by_tilt(absTiltDeg)
	if _rng.randf() > spillChance:
		return
	_spill_one_fish()
	_spillEventCooldown = max(spillEventCooldownSec, 0.0)


## 退出时取消事件订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 判定是否可入缸：仅活鱼且容量未满。
## @param item 携带物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	if item == null:
		return false
	_cleanup_stored_fish()
	if item.is_in_group(plateGroupName):
		return _can_plate_take_fish(item)
	if _storedFish.size() >= max(maxFishCount, 0):
		return false
	if not item.has_method('mark_in_tank'):
		return false
	if item.has_method('is_dead_fish') and bool(item.call('is_dead_fish')):
		return false
	return true


## 判定锚交互是否有效：空手且可携带时可从鱼缸取一条鱼到手上。
## @param anchorController 锚控制器
## @return bool
func _is_anchor_valid(anchorController: Node) -> bool:
	_cleanup_stored_fish()
	if _storedFish.is_empty():
		return false
	if anchorController == null:
		return false
	if not anchorController.has_method('can_add_carried_cargo'):
		return false
	return bool(anchorController.call('can_add_carried_cargo'))


## 物品合法时入缸缓存。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return void
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedAnchorController: Node = anchorController
	_lastPlateTakeAccepted = false
	if item != null and item.is_in_group(plateGroupName):
		_lastPlateTakeAccepted = _take_one_fish_to_plate(item)
		if _lastPlateTakeAccepted:
			AudioManager.play_sfx(ResPath.AUDIO.PICK_UP_ITEM)
			_log_interact('tank serve raw fish to plate count=%d' % _storedFish.size())
		return
	var swimRect: Rect2 = _tank_swim_rect_global()
	if item.has_method('mark_in_tank_with_bounds'):
		item.call('mark_in_tank_with_bounds', swimRect)
	else:
		item.call('mark_in_tank')
	_storedFish.append(item)
	AudioManager.play_sfx(ResPath.AUDIO.FISH_TANK_DROP)
	_log_interact('tank store success count=%d' % _storedFish.size())


## 锚交互合法时：从鱼缸取一条鱼到玩家手上。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return void
func _on_anchor_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	if _take_one_fish_to_hand(anchorController):
		AudioManager.play_sfx(ResPath.AUDIO.PICK_UP_ITEM)
		_log_interact('tank take fish to hand count=%d' % _storedFish.size())


## 失败时日志说明。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
## @return void
func _on_interact_failed(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedItem: Node = item
	var _unusedAnchorController: Node = anchorController
	_cleanup_stored_fish()
	_log_interact('tank store rejected count=%d max=%d' % [_storedFish.size(), maxFishCount])


## 控制是否消耗携带物（盘子取鱼时不消耗盘子）。
## @param item 携带物品
## @return bool
func _consume_carried_on_item_valid(item: Node) -> bool:
	if item != null and item.is_in_group(plateGroupName) and _lastPlateTakeAccepted:
		return false
	return true


## 清理无效缓存引用。
## @return void
func _cleanup_stored_fish() -> void:
	for i in range(_storedFish.size() - 1, -1, -1):
		var fishNode: Node = _storedFish[i]
		if fishNode == null or not is_instance_valid(fishNode):
			_storedFish.remove_at(i)


## 从鱼缸滑出一条鱼到地面。
## @return void
func _spill_one_fish() -> void:
	_cleanup_stored_fish()
	if _storedFish.is_empty():
		return
	var fishIndex: int = _rng.randi_range(0, _storedFish.size() - 1)
	var fishNode: Node = _storedFish[fishIndex]
	_storedFish.remove_at(fishIndex)
	if fishNode == null or not is_instance_valid(fishNode):
		return
	if not fishNode.has_method('mark_out_of_tank'):
		return
	var edgePos: Vector2 = _resolve_spill_edge_point()
	var dropPos: Vector2 = global_position + spillDropOffset
	dropPos.x += _rng.randf_range(-absf(spillDropRandomX), absf(spillDropRandomX))
	if fishNode.has_method('start_spill_from_tank_with_edge'):
		fishNode.call(
			'start_spill_from_tank_with_edge',
			edgePos,
			dropPos,
			spillToEdgeDurationSec,
			spillOutDurationSec,
			spillAnimArcHeight
		)
	elif fishNode.has_method('start_spill_from_tank'):
		fishNode.call('start_spill_from_tank', dropPos, spillOutDurationSec, spillAnimArcHeight)
	else:
		fishNode.call('mark_out_of_tank', dropPos)
	_log_interact('tank spill fish count=%d' % _storedFish.size())


## 判定盘子是否可取鱼（需有库存且盘子为空）。
## @param plate 盘子节点
## @return bool
func _can_plate_take_fish(plate: Node) -> bool:
	if plate == null:
		return false
	if _storedFish.is_empty():
		return false
	if not plate.has_method('get_food_type'):
		return false
	var plateFoodType: Variant = plate.call('get_food_type')
	if typeof(plateFoodType) != TYPE_INT:
		return false
	return int(plateFoodType) == -1


## 从鱼缸取一条鱼并装盘为生鱼料理。
## @param plate 盘子节点
## @return bool
func _take_one_fish_to_plate(plate: Node) -> bool:
	if not _can_plate_take_fish(plate):
		return false
	_cleanup_stored_fish()
	if _storedFish.is_empty():
		return false
	var fishNode: Node = _storedFish.pop_back()
	if fishNode != null and is_instance_valid(fishNode):
		_consume_item(fishNode)
	if plate.has_method('set_food_type'):
		plate.call('set_food_type', FoodConfig.FoodType.RAW_FISH)
	if plate.has_method('apply_food_texture'):
		plate.call('apply_food_texture')
	return true


## 从鱼缸取一条鱼到手上（依赖锚控制器携带能力）。
## @param anchorController 锚控制器
## @return bool
func _take_one_fish_to_hand(anchorController: Node) -> bool:
	if anchorController == null:
		return false
	if not anchorController.has_method('try_add_carried_cargo'):
		return false
	_cleanup_stored_fish()
	if _storedFish.is_empty():
		return false
	var fishNode: Node = _storedFish.pop_back()
	if fishNode == null or not is_instance_valid(fishNode):
		return false
	var accepted: bool = bool(anchorController.call('try_add_carried_cargo', fishNode))
	if accepted:
		return true
	_storedFish.append(fishNode)
	return false


## 填满鱼缸至最大容量（阶段达标时由外部调用）。
## @return void
func fill_to_max() -> void:
	_cleanup_stored_fish()
	var needed: int = max(maxFishCount, 0) - _storedFish.size()
	if needed <= 0:
		return
	var fishScene: PackedScene = ResPath.PROP_SCENES.FISH_ENTITY
	if fishScene == null:
		return
	var swimRect: Rect2 = _tank_swim_rect_global()
	for i in range(needed):
		var fishNode: Node = fishScene.instantiate()
		if fishNode == null:
			continue
		get_tree().current_scene.add_child(fishNode)
		if fishNode.has_method('mark_in_tank_with_bounds'):
			fishNode.call('mark_in_tank_with_bounds', swimRect)
		elif fishNode.has_method('mark_in_tank'):
			fishNode.call('mark_in_tank')
		_storedFish.append(fishNode)
	_log_interact('fill_to_max done count=%d' % _storedFish.size())


## 计算鱼缸内部游动范围（全局矩形）。
## @return Rect2
func _tank_swim_rect_global() -> Rect2:
	var half: Vector2 = tankSwimRectSize * 0.5
	var center: Vector2 = global_position + tankSwimRectOffset
	return Rect2(center - half, tankSwimRectSize)


## 处理风暴事件，仅在风暴阶段允许溢出事件判定。
## @param eventType 事件类型
## @param data 事件数据
## @return void
func _on_event(eventType: EventBus.EventType, data: Dictionary) -> void:
	match eventType:
		EventBus.EventType.STORM_STARTED:
			_stormSpillEnabled = true
			_stormDirection = float(data.get('direction', signf(global_rotation)))
		EventBus.EventType.STORM_DIRECTION_CHANGED:
			_stormDirection = float(data.get('direction', _stormDirection))
		EventBus.EventType.STORM_RECOVER_STARTED:
			_stormSpillEnabled = false
		EventBus.EventType.STORM_ENDED:
			_stormSpillEnabled = false
		_:
			pass


## 按当前倾斜角计算每秒溢出概率（线性插值）。
## @param absTiltDeg 绝对倾斜角（度）
## @return float
func _spill_chance_by_tilt(absTiltDeg: float) -> float:
	var minChance: float = clampf(stormSpillMinChancePerSec, 0.0, 1.0)
	var maxChance: float = clampf(stormSpillMaxChancePerSec, minChance, 1.0)
	var threshold: float = max(spillTiltThresholdDeg, 0.0)
	var maxTilt: float = max(stormSpillMaxTiltDeg, threshold + 0.01)
	var t: float = clampf((absTiltDeg - threshold) / (maxTilt - threshold), 0.0, 1.0)
	return lerpf(minChance, maxChance, t)


## 计算“倾斜方向上沿角点”作为第一段动画目标点。
## @return Vector2
func _resolve_spill_edge_point() -> Vector2:
	var half: Vector2 = tankSwimRectSize * 0.5
	var leftTopLocal: Vector2 = tankSwimRectOffset + Vector2(-half.x, -half.y)
	var rightTopLocal: Vector2 = tankSwimRectOffset + Vector2(half.x, -half.y)
	var preferRight: bool = rad_to_deg(global_rotation) >= 0.0
	var targetLocal: Vector2 = rightTopLocal if preferRight else leftTopLocal
	return to_global(targetLocal)
