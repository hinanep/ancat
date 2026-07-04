extends InteractableBase

## 鱼缸交互参数：入缸容量、倾斜滑出与滑出落点配置。
## 盘子分组名（用于从鱼缸取鱼装盘）。
@export var plateGroupName: StringName = 'Plate'
## 鱼缸最大存储数量。
@export var maxFishCount: int = 3
## 触发滑出的船体倾斜阈值（度）。
@export var spillTiltThresholdDeg: float = 8.0
## 持续倾斜时连续滑出间隔（秒）。
@export var spillIntervalSec: float = 0.5
## 滑出落点基础偏移。
@export var spillDropOffset: Vector2 = Vector2(0.0, 22.0)
## 滑出落点随机 X 振幅。
@export var spillDropRandomX: float = 18.0
## 鱼缸内游动范围尺寸。
@export var tankSwimRectSize: Vector2 = Vector2(44.0, 16.0)
## 鱼缸内游动范围偏移。
@export var tankSwimRectOffset: Vector2 = Vector2(0.0, 2.0)
## 溢出动画时长（秒）。
@export var spillAnimDurationSec: float = 0.28
## 溢出动画抛物线高度（像素）。
@export var spillAnimArcHeight: float = 22.0

var _storedFish: Array[Node] = []
var _spillCooldown: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lastPlateTakeAccepted: bool = false


## 初始化随机数。
## @return void
func _ready() -> void:
	super._ready()
	_rng.randomize()


## 每帧处理倾斜滑出。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	_spillCooldown = max(_spillCooldown - delta, 0.0)
	_cleanup_stored_fish()
	if _storedFish.is_empty():
		return
	if _spillCooldown > 0.0:
		return
	if absf(rad_to_deg(global_rotation)) < max(spillTiltThresholdDeg, 0.0):
		return
	_spill_one_fish()
	_spillCooldown = max(spillIntervalSec, 0.1)


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
			_log_interact('tank serve raw fish to plate count=%d' % _storedFish.size())
		return
	var swimRect: Rect2 = _tank_swim_rect_global()
	if item.has_method('mark_in_tank_with_bounds'):
		item.call('mark_in_tank_with_bounds', swimRect)
	else:
		item.call('mark_in_tank')
	_storedFish.append(item)
	_log_interact('tank store success count=%d' % _storedFish.size())


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
	var fishNode: Node = _storedFish.pop_back()
	if fishNode == null or not is_instance_valid(fishNode):
		return
	if not fishNode.has_method('mark_out_of_tank'):
		return
	var dropPos: Vector2 = global_position + spillDropOffset
	dropPos.x += _rng.randf_range(-absf(spillDropRandomX), absf(spillDropRandomX))
	if fishNode.has_method('start_spill_from_tank'):
		fishNode.call('start_spill_from_tank', dropPos, spillAnimDurationSec, spillAnimArcHeight)
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


## 计算鱼缸内部游动范围（全局矩形）。
## @return Rect2
func _tank_swim_rect_global() -> Rect2:
	var half: Vector2 = tankSwimRectSize * 0.5
	var center: Vector2 = global_position + tankSwimRectOffset
	return Rect2(center - half, tankSwimRectSize)
