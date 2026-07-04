extends MovableCargo

## 盘子：用于盛放烹饪完成的食物，加入 Plate 分组供锅识别。
## @emptyPlateTexture 空盘纹理
@export var emptyPlateTexture: Texture2D = preload('res://assets/textures/烹饪/46. Plate.png')

var _foodType: int = -1

func _ready() -> void:
	super._ready()
	add_to_group('Plate')
	_apply_texture(emptyPlateTexture)


## 设置盘子内食物类型。
## @param foodType 食物类型
## @return void
func set_food_type(foodType: int) -> void:
	_foodType = foodType


## 获取盘子食物类型。
## @return int
func get_food_type() -> int:
	return _foodType


## 清空盘子食物并恢复空盘纹理。
## @return void
func clear_food() -> void:
	_foodType = -1
	_apply_texture(emptyPlateTexture)


## 按当前 foodType 应用纹理。
## @return void
func apply_food_texture() -> void:
	if _foodType == -1:
		_apply_texture(emptyPlateTexture)
		return
	var texture: Texture2D = FoodConfig.get_atlas_texture(_foodType)
	if texture != null:
		_apply_texture(texture)


## 应用纹理到盘子精灵。
## @param texture 目标纹理
func _apply_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	var sprite: Sprite2D = get_node_or_null('46_Plate') as Sprite2D
	if sprite == null:
		return
	sprite.texture = texture
