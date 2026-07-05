class_name CookPlateCollectPrompt
extends Node2D

## 厨具成品收集提示：无盘料理贴图 + 盘子浮标与箭头弹跳动画。
var _visibleFoodType: int = -1

@onready var _dishSprite: Sprite2D = $DishSprite
@onready var _floatPlayer: AnimationPlayer = $PromptFloatPlayer


## 初始化盘子浮标贴图。
## @return void
func _ready() -> void:
	var plateIcon: Sprite2D = get_node_or_null('PromptContainer/PlateIcon') as Sprite2D
	if plateIcon != null:
		plateIcon.texture = ResPath.TEXTURES.PLATE_EMPTY
	hide_result()


## 显示指定成品类型并播放浮标弹跳。
## @param foodType 食物类型
## @return void
func show_result(foodType: int) -> void:
	if foodType < 0:
		hide_result()
		return
	if _visibleFoodType != foodType:
		_visibleFoodType = foodType
		var dishTexture: Texture2D = FoodConfig.get_preview_atlas_texture(foodType)
		if dishTexture != null and _dishSprite != null:
			_dishSprite.texture = dishTexture
	visible = true
	if _floatPlayer != null and _floatPlayer.current_animation != 'float':
		_floatPlayer.play('float')


## 隐藏成品与浮标提示。
## @return void
func hide_result() -> void:
	_visibleFoodType = -1
	visible = false
	if _floatPlayer != null:
		_floatPlayer.stop()
