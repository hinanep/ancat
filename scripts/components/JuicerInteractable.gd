extends InteractableBase

## 榨汁机：水果入机生成果酱，内部最多缓存三份，盘子可取出。
## @plateGroupName 盘子组
## @maxStoredJams 最大缓存份数
## @machineAtlas 榨汁机图集
## @atlasCellSize 图集单格尺寸
@export var plateGroupName: StringName = 'Plate'
@export var maxStoredJams: int = 1
@export var machineAtlas: Texture2D = ResPath.TEXTURES.JUICER_ATLAS
@export var atlasCellSize: Vector2 = Vector2(32.0, 32.0)
## 空机器贴图区域（左上角）。
@export var emptyRegion: Rect2 = Rect2(0.0, 0.0, 32.0, 32.0)
## 三份库存时的水果状态区域（左到右：苹果、桃子、梨）。
@export var stock3Regions: Array[Rect2] = [
	Rect2(32.0, 0.0, 32.0, 32.0),
	Rect2(64.0, 0.0, 32.0, 32.0),
	Rect2(96.0, 0.0, 32.0, 32.0)
]
## 两份库存时的水果状态区域（左到右：苹果、桃子、梨）。
@export var stock2Regions: Array[Rect2] = [
	Rect2(32.0, 32.0, 32.0, 32.0),
	Rect2(64.0, 32.0, 32.0, 32.0),
	Rect2(96.0, 32.0, 32.0, 32.0)
]
## 一份库存时的水果状态区域（左到右：苹果、桃子、梨）。
@export var stock1Regions: Array[Rect2] = [
	Rect2(32.0, 64.0, 32.0, 32.0),
	Rect2(64.0, 64.0, 32.0, 32.0),
	Rect2(96.0, 64.0, 32.0, 32.0)
]
## 榨汁抖动强度（像素）。
@export var shakeOffsetPx: float = 4.0
## 榨汁抖动时长（秒）。
@export var shakeDurationSec: float = 0.12

var _storedJams: Array[int] = []
var _currentJamType: int = -1
var _juicerSpriteBasePos: Vector2 = Vector2.ZERO

@onready var _juicerSprite: Sprite2D = get_parent().get_node_or_null('Sprite2D') as Sprite2D


## 初始化榨汁机显示。
## @return void
func _ready() -> void:
	super._ready()
	if _juicerSprite != null:
		_juicerSpriteBasePos = _juicerSprite.position
	_update_machine_visual()


## 判定交互物是否合法。
## @param item 候选物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	if item == null:
		return false
	if item.is_in_group(plateGroupName):
		return not _storedJams.is_empty()
	var fruitType: int = _resolve_fruit_type(item)
	if fruitType == -1:
		return false
	if _storedJams.size() >= max(maxStoredJams, 1):
		return false
	var jamType: int = FoodConfig.fruit_to_jam(fruitType)
	if jamType == -1:
		return false
	if _currentJamType != -1 and jamType != _currentJamType:
		return false
	return true


## 处理合法交互。
## @param player 玩家节点
## @param item 携带物
## @param anchorController 锚控制器
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedAnchor: Node = anchorController
	if item.is_in_group(plateGroupName):
		if _storedJams.is_empty():
			return
		var jamType: int = _storedJams.pop_front()
		if _storedJams.is_empty():
			_currentJamType = -1
		if item.has_method('set_food_type'):
			item.call('set_food_type', jamType)
		if item.has_method('apply_food_texture'):
			item.call('apply_food_texture')
		_update_machine_visual()
		AudioManager.play_sfx(ResPath.AUDIO.POUR_JAM_JUICE)
		_log_interact('plate took jam from juicer')
		return
	var fruitType: int = _resolve_fruit_type(item)
	if fruitType == -1:
		return
	var jamType: int = FoodConfig.fruit_to_jam(fruitType)
	if jamType == -1:
		return
	if _currentJamType == -1:
		_currentJamType = jamType
	_consume_item(item)
	_storedJams.append(jamType)
	_play_juice_shake()
	_update_machine_visual()
	_log_interact('fruit processed to jam, stored=%d' % _storedJams.size())


## 控制是否消耗携带物。
## @param item 携带物
## @return bool
func _consume_carried_on_item_valid(item: Node) -> bool:
	if item == null:
		return true
	if item.is_in_group(plateGroupName):
		return false
	return true


## 解析候选物是否为可榨汁水果。
## @param item 候选物品
## @return int
func _resolve_fruit_type(item: Node) -> int:
	if item == null:
		return -1
	if item.has_method('get_food_type'):
		var foodTypeVariant: Variant = item.call('get_food_type')
		if typeof(foodTypeVariant) == TYPE_INT:
			var foodType: int = int(foodTypeVariant)
			var kind: String = FoodConfig.get_kind(foodType)
			if kind == 'fruit':
				return foodType
	var tag: String = _resolve_item_tag(item)
	if tag == 'apple':
		return FoodConfig.FoodType.APPLE
	if tag == 'peach':
		return FoodConfig.FoodType.PEACH
	if tag == 'pear':
		return FoodConfig.FoodType.PEAR
	return -1


## 更新榨汁机 atlas 显示。
## @return void
func _update_machine_visual() -> void:
	if _juicerSprite == null:
		return
	if machineAtlas != null:
		_juicerSprite.texture = machineAtlas
	_juicerSprite.region_enabled = true
	_juicerSprite.region_rect = _resolve_display_region()


## 解析当前应显示的图集区域。
## @return Rect2
func _resolve_display_region() -> Rect2:
	if _storedJams.is_empty() or _currentJamType == -1:
		return emptyRegion
	var fruitIndex: int = _resolve_fruit_index_by_jam(_currentJamType)
	if fruitIndex < 0:
		return emptyRegion
	var count: int = clampi(_storedJams.size(), 1, max(maxStoredJams, 1))
	if count >= 3 and fruitIndex < stock3Regions.size():
		return stock3Regions[fruitIndex]
	if count == 2 and fruitIndex < stock2Regions.size():
		return stock2Regions[fruitIndex]
	if count == 1 and fruitIndex < stock1Regions.size():
		return stock1Regions[fruitIndex]
	return emptyRegion


## 根据果酱类型映射到水果索引。
## @param jamType 果酱类型
## @return int
func _resolve_fruit_index_by_jam(jamType: int) -> int:
	if jamType == FoodConfig.FoodType.APPLE_JAM:
		return 0
	if jamType == FoodConfig.FoodType.PEACH_JAM:
		return 1
	if jamType == FoodConfig.FoodType.PEAR_JAM:
		return 2
	return -1


## 播放榨汁抖动动画。
## @return void
func _play_juice_shake() -> void:
	if _juicerSprite == null:
		return
	AudioManager.play_sfx_loop('juicer_machine', ResPath.AUDIO.JUICER)
	var duration: float = max(shakeDurationSec, 0.03)
	var offset: float = max(shakeOffsetPx, 0.0)
	var tween: Tween = create_tween()
	tween.tween_property(_juicerSprite, 'position', _juicerSpriteBasePos + Vector2(offset, 0.0), duration * 0.33)
	tween.tween_property(_juicerSprite, 'position', _juicerSpriteBasePos + Vector2(-offset, 0.0), duration * 0.33)
	tween.tween_property(_juicerSprite, 'position', _juicerSpriteBasePos, duration * 0.34)
	tween.finished.connect(_on_shake_finished)


## 榨汁抖动结束后停止循环音效。
## @return void
func _on_shake_finished() -> void:
	AudioManager.stop_sfx_loop('juicer_machine')
