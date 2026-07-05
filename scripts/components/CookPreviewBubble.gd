class_name CookPreviewBubble
extends Node2D

## 厨具烹饪成品预览气泡：PlateDispenser 风格图标 + 上下弹跳动画。
var _visibleFoodType: int = -1

@onready var _foodIcon: Sprite2D = $PromptContainer/FoodIcon
@onready var _floatPlayer: AnimationPlayer = $PromptFloatPlayer


## 显示指定食物类型的预览并播放弹跳动画。
## @param foodType 食物类型
## @return void
func show_preview(foodType: int) -> void:
	if foodType < 0:
		hide_preview()
		return
	if _visibleFoodType != foodType:
		_visibleFoodType = foodType
		var foodTexture: Texture2D = FoodConfig.get_preview_atlas_texture(foodType)
		if foodTexture != null and _foodIcon != null:
			_foodIcon.texture = foodTexture
	visible = true
	if _floatPlayer != null and _floatPlayer.current_animation != 'float':
		_floatPlayer.play('float')


## 隐藏预览并停止弹跳动画。
## @return void
func hide_preview() -> void:
	_visibleFoodType = -1
	visible = false
	if _floatPlayer != null:
		_floatPlayer.stop()
