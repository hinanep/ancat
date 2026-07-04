extends MovableCargo

## 水果货物：用于榨汁与顾客需求交付。
## @fruitType 水果类型（苹果/桃子/梨）
@export var fruitType: int = FoodConfig.FoodType.APPLE


## 初始化水果数据。
func _ready() -> void:
	super._ready()
	add_to_group('Fruit')
	deliveryTag = FoodConfig.get_tag(fruitType)
	_apply_food_texture()
	#region agent log
	_agent_debug_emit(
		'H1',
		'FruitCargo.gd:_ready',
		'fruit cargo ready snapshot',
		{
			'name': name,
			'fruitType': fruitType,
			'deliveryTag': deliveryTag
		}
	)
	#endregion


## 获取水果食物类型。
## @return int
func get_food_type() -> int:
	return fruitType


## 应用对应水果纹理。
func _apply_food_texture() -> void:
	var texture: Texture2D = FoodConfig.get_atlas_texture(fruitType)
	if texture == null:
		return
	var sprite: Sprite2D = get_node_or_null('Sprite2D') as Sprite2D
	if sprite == null:
		return
	sprite.texture = texture
