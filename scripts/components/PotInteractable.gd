extends InteractableBase

## 锅交互逻辑：接受 Cookable 分组食材入锅，接受 Plate 分组盘子取出已熟食材。
## @cookableGroupName 可烹饪食材的 Godot 分组名
## @plateGroupName 盘子的 Godot 分组名
## @cookedPlateTexture 装盘后盘子使用的图集纹理
## @cookedPlateAtlasRegion 从图集中提取的帧区域
@export var cookableGroupName: StringName = 'Cookable'
@export var plateGroupName: StringName = 'Plate'
@export var cookedPlateTexture: Texture2D = preload('res://assets/textures/烹饪/料理.png')
@export var cookedPlateAtlasRegion: Rect2 = Rect2(0.0, 0.0, 32.0, 29.0)


## 物品合法性判定：Cookable + 锅空 或 Plate + 已熟。
## @param item 候选物品
## @return bool
func _is_item_valid(item: Node) -> bool:
	if item == null:
		return false
	var pot: Node = get_parent()
	if pot == null or not pot.has_method('has_food'):
		return false
	if item.is_in_group(cookableGroupName) and not pot.call('has_food'):
		return true
	if item.is_in_group(plateGroupName) and pot.call('has_food') and pot.call('is_cooked'):
		return true
	return false


## 物品合法时的处理：食材入锅或已熟食材转移到盘子。
## @param player 玩家节点
## @param item 携带物品
## @param anchorController 锚控制器
func _on_item_valid(player: Node, item: Node, anchorController: Node) -> void:
	var _unusedPlayer: Node = player
	var _unusedAnchorController: Node = anchorController
	var pot: Node = get_parent()
	if pot == null:
		return
	if item.is_in_group(cookableGroupName):
		# 食材入锅
		pot.call('add_food', item)
		_log_interact('food added to pot')
		return
	if item.is_in_group(plateGroupName):
		var food: Node2D = pot.call('take_food')
		if food == null:
			return
		food.queue_free()
		_apply_cooked_texture_to_plate(item)
		_log_interact('food served to plate')


## 物品合法时是否消耗携带物：食材消耗，盘子保留在手中。
## @param item 携带物品
## @return bool
func _consume_carried_on_item_valid(item: Node) -> bool:
	if item == null:
		return true
	if item.is_in_group(plateGroupName):
		return false
	return true


## 将盘子的 Sprite2D 纹理替换为料理图集帧。
## @param plate 盘子节点
## @return void
func _apply_cooked_texture_to_plate(plate: Node) -> void:
	if cookedPlateTexture == null:
		return
	var sprite: Sprite2D = null
	for child in plate.get_children():
		if child is Sprite2D:
			sprite = child as Sprite2D
			break
	if sprite == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = cookedPlateTexture
	atlas.region = cookedPlateAtlasRegion
	sprite.texture = atlas
