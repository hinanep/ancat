extends Node2D

## GameWorld 背景视差控制器：三层横向循环滚动，风暴时切换 sky/cloud 贴图。

## sky 层滚动速度（像素/秒）
@export var skyScrollSpeed: float = 5.0
## cloud 层滚动速度（像素/秒）
@export var cloudScrollSpeed: float = 15.0
## city 层滚动速度（像素/秒）
@export var cityScrollSpeed: float = 30.0
## 平静 sky 贴图
@export var skyCalmTexture: Texture2D = preload('res://assets/textures/Forever Morning/0_sky.png')
## 风暴 sky 贴图
@export var skyStormTexture: Texture2D = preload('res://assets/textures/Forever Morning/sky_storm.png')
## 平静 cloud 贴图
@export var cloudCalmTexture: Texture2D = preload('res://assets/textures/Forever Morning/2_clouds.png')
## 风暴 cloud 贴图
@export var cloudStormTexture: Texture2D = preload('res://assets/textures/Forever Morning/cloud_storm.png')

const _SKY_NODE_PATH: NodePath = ^'0Sky'
const _CLOUD_NODE_PATH: NodePath = ^'2Clouds6'
const _CITY_NODE_PATH: NodePath = ^'3City'

var _skyLayer: _ScrollLayer
var _cloudLayer: _ScrollLayer
var _cityLayer: _ScrollLayer


## 单层横向循环滚动状态。
## @primary 主 Sprite2D
## @copy 循环副本 Sprite2D
## @basePosition 初始位置
## @calmTexture 平静贴图
## @calmScale 平静缩放
## @stormTexture 风暴贴图（可为 null）
## @scrollSpeed 滚动速度
## @scrollOffset 累计滚动偏移
## @tileWidth 单块循环宽度
## @isStormTexture 是否使用风暴贴图
class _ScrollLayer:
	var primary: Sprite2D
	var copy: Sprite2D
	var basePosition: Vector2 = Vector2.ZERO
	var calmTexture: Texture2D
	var calmScale: Vector2 = Vector2.ONE
	var stormTexture: Texture2D
	var scrollSpeed: float = 0.0
	var scrollOffset: float = 0.0
	var tileWidth: float = 0.0
	var isStormTexture: bool = false


## 初始化三层滚动并订阅风暴事件。
## @return void
func _ready() -> void:
	var skySprite: Sprite2D = get_node_or_null(_SKY_NODE_PATH) as Sprite2D
	var cloudSprite: Sprite2D = get_node_or_null(_CLOUD_NODE_PATH) as Sprite2D
	var citySprite: Sprite2D = get_node_or_null(_CITY_NODE_PATH) as Sprite2D
	if skySprite == null or cloudSprite == null or citySprite == null:
		push_error('BackgroundParallaxController: missing sky/cloud/city sprite')
		return
	_skyLayer = _setup_scroll_layer(skySprite, skyScrollSpeed, skyCalmTexture, skyStormTexture)
	_cloudLayer = _setup_scroll_layer(cloudSprite, cloudScrollSpeed, cloudCalmTexture, cloudStormTexture)
	_cityLayer = _setup_scroll_layer(citySprite, cityScrollSpeed, citySprite.texture, null)
	EventBus.subscribe(_on_event)


## 退出时取消事件订阅。
## @return void
func _exit_tree() -> void:
	EventBus.unsubscribe(_on_event)


## 每帧更新三层滚动位置。
## @param delta 帧间隔（秒）
## @return void
func _process(delta: float) -> void:
	_update_layer_scroll(_skyLayer, delta)
	_update_layer_scroll(_cloudLayer, delta)
	_update_layer_scroll(_cityLayer, delta)


## 响应风暴事件切换或恢复背景贴图。
## @param event_type 事件类型
## @param _data 事件数据
## @return void
func _on_event(event_type: EventBus.EventType, _data: Dictionary) -> void:
	match event_type:
		EventBus.EventType.STORM_STARTED:
			_apply_storm_textures()
		EventBus.EventType.STORM_ENDED:
			_restore_calm_textures()


## 创建单层双副本循环结构。
## @param primary 主 Sprite2D
## @param speed 滚动速度
## @param calmTexture 平静贴图
## @param stormTexture 风暴贴图
## @return _ScrollLayer
func _setup_scroll_layer(primary: Sprite2D, speed: float, calmTexture: Texture2D, stormTexture: Texture2D) -> _ScrollLayer:
	var layer: _ScrollLayer = _ScrollLayer.new()
	layer.primary = primary
	layer.copy = primary.duplicate() as Sprite2D
	layer.copy.name = '%sCopy' % primary.name
	primary.get_parent().add_child(layer.copy)
	layer.basePosition = primary.position
	layer.calmTexture = calmTexture if calmTexture != null else primary.texture
	layer.calmScale = primary.scale
	layer.stormTexture = stormTexture
	layer.scrollSpeed = speed
	primary.texture = layer.calmTexture
	_rebuild_layer_tile(layer)
	_apply_scroll_positions(layer)
	return layer


## 重算单层循环宽度并同步副本贴图与缩放。
## @param layer 滚动层状态
## @return void
func _rebuild_layer_tile(layer: _ScrollLayer) -> void:
	if layer == null or layer.primary == null or layer.copy == null:
		return
	var texture: Texture2D = layer.primary.texture
	if texture == null:
		layer.tileWidth = 0.0
		return
	layer.tileWidth = float(texture.get_width()) * absf(layer.primary.scale.x)
	layer.copy.texture = layer.primary.texture
	layer.copy.scale = layer.primary.scale


## 按当前 scrollOffset 更新主副本与循环副本位置。
## @param layer 滚动层状态
## @return void
func _apply_scroll_positions(layer: _ScrollLayer) -> void:
	if layer == null or layer.tileWidth <= 0.0:
		return
	var x: float = layer.basePosition.x - fmod(layer.scrollOffset, layer.tileWidth)
	layer.primary.position = Vector2(x, layer.basePosition.y)
	layer.copy.position = Vector2(x + layer.tileWidth, layer.basePosition.y)


## 推进滚动偏移并刷新位置。
## @param layer 滚动层状态
## @param delta 帧间隔（秒）
## @return void
func _update_layer_scroll(layer: _ScrollLayer, delta: float) -> void:
	if layer == null or layer.tileWidth <= 0.0:
		return
	layer.scrollOffset += layer.scrollSpeed * delta
	_apply_scroll_positions(layer)


## 切换 sky/cloud 为风暴贴图。
## @return void
func _apply_storm_textures() -> void:
	_set_layer_storm(_skyLayer, true)
	_set_layer_storm(_cloudLayer, true)


## 恢复 sky/cloud 平静贴图与缩放。
## @return void
func _restore_calm_textures() -> void:
	_set_layer_storm(_skyLayer, false)
	_set_layer_storm(_cloudLayer, false)


## 设置单层风暴或平静贴图，sky 风暴时按显示尺寸重算缩放。
## @param layer 滚动层状态
## @param useStorm 是否使用风暴贴图
## @return void
func _set_layer_storm(layer: _ScrollLayer, useStorm: bool) -> void:
	if layer == null or layer.primary == null:
		return
	if useStorm:
		if layer.stormTexture == null:
			return
		layer.primary.texture = layer.stormTexture
		if layer == _skyLayer:
			var displaySize: Vector2 = Vector2(layer.calmTexture.get_width(), layer.calmTexture.get_height()) * layer.calmScale
			layer.primary.scale = Vector2(
				displaySize.x / float(layer.stormTexture.get_width()),
				displaySize.y / float(layer.stormTexture.get_height())
			)
		layer.isStormTexture = true
	else:
		layer.primary.texture = layer.calmTexture
		layer.primary.scale = layer.calmScale
		layer.isStormTexture = false
	_rebuild_layer_tile(layer)
	_apply_scroll_positions(layer)
