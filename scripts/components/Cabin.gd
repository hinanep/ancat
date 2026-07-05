@tool
class_name Cabin
extends Node2D

## Cabin 节点配置：控制尺寸、门洞、地板洞、天花板开关与 TileMap 贴图坐标。
## @tile_size 单格像素尺寸
## @cabin_width 船舱宽度（像素）
## @cabin_height 船舱高度（像素）
## @door_height 开门时下半段挖空高度（像素）
## @left_door_open 左门开关
## @right_door_open 右门开关
## @floor_hole_position 地板洞相对左内缘偏移（像素）
## @floor_hole_size 地板洞宽度（像素）
## @ceiling_hole_position 天花板洞相对左内缘偏移（像素）
## @ceiling_hole_size 天花板洞宽度（像素）
## @render_ceiling 是否渲染天花板
## @render_corner_* 四个角是否渲染
## @tile* 各连接状态对应的图块 atlas 坐标
@export var tile_size: int = 16
@export var cabin_width: float = 320.0:
	set(value):
		_set_cabin_size(value, _cabinHeight)
	get:
		return _cabinWidth

@export var cabin_height: float = 240.0:
	set(value):
		_set_cabin_size(_cabinWidth, value)
	get:
		return _cabinHeight

@export var door_height: float = 120.0:
	set(value):
		_doorHeight = max(value, 0.0)
		_rebuild_all()
	get:
		return _doorHeight

@export var left_door_open: bool = false:
	set(value):
		_leftDoorOpen = value
		_rebuild_all()
	get:
		return _leftDoorOpen

@export var right_door_open: bool = false:
	set(value):
		_rightDoorOpen = value
		_rebuild_all()
	get:
		return _rightDoorOpen

@export var floor_hole_position: float = 0.0:
	set(value):
		_floorHolePosition = max(value, 0.0)
		_rebuild_all()
	get:
		return _floorHolePosition

@export var floor_hole_size: float = 0.0:
	set(value):
		_floorHoleSize = max(value, 0.0)
		_rebuild_all()
	get:
		return _floorHoleSize

@export var ceiling_hole_position: float = 0.0:
	set(value):
		_ceilingHolePosition = max(value, 0.0)
		_rebuild_all()
	get:
		return _ceilingHolePosition

@export var ceiling_hole_size: float = 0.0:
	set(value):
		_ceilingHoleSize = max(value, 0.0)
		_rebuild_all()
	get:
		return _ceilingHoleSize

@export var render_ceiling: bool = true:
	set(value):
		_renderCeiling = value
		_rebuild_all()
	get:
		return _renderCeiling

@export var render_corner_ne: bool = true:
	set(value):
		_renderCornerNe = value
		_rebuild_all()
	get:
		return _renderCornerNe

@export var render_corner_nw: bool = true:
	set(value):
		_renderCornerNw = value
		_rebuild_all()
	get:
		return _renderCornerNw

@export var render_corner_se: bool = true:
	set(value):
		_renderCornerSe = value
		_rebuild_all()
	get:
		return _renderCornerSe

@export var render_corner_sw: bool = true:
	set(value):
		_renderCornerSw = value
		_rebuild_all()
	get:
		return _renderCornerSw


@export var tile_corner_ne: Vector2i = Vector2i(13, 0)
@export var tile_corner_nw: Vector2i = Vector2i(0, 0)
@export var tile_corner_se: Vector2i = Vector2i(13, 8)
@export var tile_corner_sw: Vector2i = Vector2i(0, 8)
@export var tile_end_n: Vector2i = Vector2i(1, 0)
@export var tile_end_s: Vector2i = Vector2i(12, 8)
@export var tile_end_e: Vector2i = Vector2i(13, 7)
@export var tile_end_w: Vector2i = Vector2i(0, 1)


signal door_state_changed(side: String, isOpen: bool)

const INTERIOR_DECOR_WIDTH: float = 320.0
const INTERIOR_DECOR_HEIGHT: float = 240.0
const SOURCE_ID: int = 0
const COLLISION_LAYER_ID: int = 0
const MASK_N: int = 1
const MASK_E: int = 2
const MASK_S: int = 4
const MASK_W: int = 8

var _cabinWidth: float = 320.0
var _cabinHeight: float = 240.0
var _doorHeight: float = 120.0
var _leftDoorOpen: bool = false
var _rightDoorOpen: bool = false
var _floorHolePosition: float = 0.0
var _floorHoleSize: float = 0.0
var _ceilingHolePosition: float = 0.0
var _ceilingHoleSize: float = 0.0
var _renderCeiling: bool = true
var _renderCornerNe: bool = true
var _renderCornerNw: bool = true
var _renderCornerSe: bool = true
var _renderCornerSw: bool = true

var _visualLayer: TileMapLayer
var _tileSet: TileSet
var _atlasSource: TileSetAtlasSource
var _sourceId: int = SOURCE_ID


## 初始化：加入分组并构建 tileset/网格。
## @return void
func _ready() -> void:
	add_to_group('Cabin')
	_cache_nodes()
	_ensure_tileset()
	_rebuild_all()


## 对外 API：打开左门。
## @return void
func open_left_door() -> void:
	if _leftDoorOpen:
		return
	_leftDoorOpen = true
	door_state_changed.emit('left', true)
	_rebuild_all()


## 对外 API：关闭左门。
## @return void
func close_left_door() -> void:
	if not _leftDoorOpen:
		return
	_leftDoorOpen = false
	door_state_changed.emit('left', false)
	_rebuild_all()


## 对外 API：打开右门。
## @return void
func open_right_door() -> void:
	if _rightDoorOpen:
		return
	_rightDoorOpen = true
	door_state_changed.emit('right', true)
	_rebuild_all()


## 对外 API：关闭右门。
## @return void
func close_right_door() -> void:
	if not _rightDoorOpen:
		return
	_rightDoorOpen = false
	door_state_changed.emit('right', false)
	_rebuild_all()


## 判断全局坐标是否位于舱室内部可活动区域（地板内区）。
## @param pointGlobal 全局坐标
## @return bool
func contains_interior_point(pointGlobal: Vector2) -> bool:
	var localPos: Vector2 = to_local(pointGlobal)
	var widthPixels: float = float(_grid_cols() * tile_size)
	var heightPixels: float = float(_grid_rows() * tile_size)
	var visualAnchor: Vector2 = Vector2(-widthPixels * 0.5, -heightPixels * 0.5)
	var decorOffset: Vector2 = Vector2(
		(widthPixels - INTERIOR_DECOR_WIDTH) * 0.5,
		(heightPixels - INTERIOR_DECOR_HEIGHT) * 0.5
	)
	var decorAnchor: Vector2 = visualAnchor + decorOffset
	var interiorRect: Rect2 = Rect2(decorAnchor, Vector2(INTERIOR_DECOR_WIDTH, INTERIOR_DECOR_HEIGHT))
	return interiorRect.has_point(localPos)


## 获取舱室地板内区矩形（舱室本地坐标）。
## @return Rect2
func get_interior_rect_local() -> Rect2:
	var widthPixels: float = float(_grid_cols() * tile_size)
	var heightPixels: float = float(_grid_rows() * tile_size)
	var visualAnchor: Vector2 = Vector2(-widthPixels * 0.5, -heightPixels * 0.5)
	var decorOffset: Vector2 = Vector2(
		(widthPixels - INTERIOR_DECOR_WIDTH) * 0.5,
		(heightPixels - INTERIOR_DECOR_HEIGHT) * 0.5
	)
	var decorAnchor: Vector2 = visualAnchor + decorOffset
	return Rect2(decorAnchor, Vector2(INTERIOR_DECOR_WIDTH, INTERIOR_DECOR_HEIGHT))


## 将全局坐标限制在本舱地板内区。
## @param pointGlobal 全局坐标
## @param margin 内区边距（像素）
## @return Vector2
func clamp_global_to_interior(pointGlobal: Vector2, margin: float = 0.0) -> Vector2:
	var interiorRect: Rect2 = get_interior_rect_local()
	var localPos: Vector2 = to_local(pointGlobal)
	var edge: float = max(margin, 0.0)
	localPos.x = clampf(localPos.x, interiorRect.position.x + edge, interiorRect.position.x + interiorRect.size.x - edge)
	localPos.y = clampf(localPos.y, interiorRect.position.y + edge, interiorRect.position.y + interiorRect.size.y - edge)
	return to_global(localPos)


## 将全局坐标限制在本舱外壳包围范围内。
## @param pointGlobal 全局坐标
## @param margin 边距（像素）
## @return Vector2
func clamp_global_to_bounds(pointGlobal: Vector2, margin: float = 0.0) -> Vector2:
	var halfW: float = _cabinWidth * 0.5
	var halfH: float = _cabinHeight * 0.5
	var localPos: Vector2 = to_local(pointGlobal)
	var edge: float = max(margin, 0.0)
	localPos.x = clampf(localPos.x, -halfW + edge, halfW - edge)
	localPos.y = clampf(localPos.y, -halfH + edge, halfH - edge)
	return to_global(localPos)


## 判断全局坐标是否位于舱室外壳包围范围内（用于玩家放锚等）。
## @param pointGlobal 全局坐标
## @return bool
func contains_bounds_point(pointGlobal: Vector2) -> bool:
	var localPos: Vector2 = to_local(pointGlobal)
	var halfW: float = _cabinWidth * 0.5
	var halfH: float = _cabinHeight * 0.5
	return localPos.x >= -halfW and localPos.x <= halfW and localPos.y >= -halfH and localPos.y <= halfH


## 更新尺寸并触发重建。
## @param width 宽度（像素）
## @param height 高度（像素）
## @return void
func _set_cabin_size(width: float, height: float) -> void:
	_cabinWidth = max(width, float(tile_size) * 4.0)
	_cabinHeight = max(height, float(tile_size) * 4.0)
	_doorHeight = min(max(_doorHeight, 0.0), _cabinHeight)
	_rebuild_all()


## 主重建入口：刷新 TileMap 视觉与 TileMap 碰撞。
## @return void
func _rebuild_all() -> void:
	if not is_inside_tree():
		return
	_cache_nodes()
	if _visualLayer == null:
		return
	_ensure_tileset()
	if _tileSet == null or _atlasSource == null:
		return
	_update_layer_anchor_to_center()
	_clear_layers()

	var wallCells: Dictionary = {}
	_fill_boundary_cells(wallCells)
	_apply_door_openings(wallCells)
	_apply_floor_hole(wallCells)
	_apply_ceiling_ownership(wallCells)
	_apply_ceiling_hole(wallCells)
	_apply_corner_toggles(wallCells)
	_draw_visual_cells(wallCells)


## 缓存场景节点引用。
## @return void
func _cache_nodes() -> void:
	var visuals: Node = get_node_or_null('Visuals')
	if visuals == null:
		var newVisuals: Node2D = Node2D.new()
		newVisuals.name = 'Visuals'
		add_child(newVisuals)
		visuals = newVisuals

	_visualLayer = get_node_or_null('Visuals/VisualLayer')
	if _visualLayer == null:
		_visualLayer = TileMapLayer.new()
		_visualLayer.name = 'VisualLayer'
		visuals.add_child(_visualLayer)

## 构建 TileSet 与碰撞图块定义。
## @return void
func _ensure_tileset() -> void:
	if _visualLayer == null:
		return

	_tileSet = _visualLayer.tile_set
	if _tileSet == null:
		push_error('Cabin: VisualLayer.tile_set 未设置，请绑定 resources/tilesets/walls.tres')
		_atlasSource = null
		return

	_sourceId = SOURCE_ID
	if not _tileSet.has_source(_sourceId):
		if _tileSet.get_source_count() <= 0:
			push_error('Cabin: TileSet 没有可用 source')
			_atlasSource = null
			return
		_sourceId = _tileSet.get_source_id(0)

	var existingSource: TileSetSource = _tileSet.get_source(_sourceId)
	if not (existingSource is TileSetAtlasSource):
		push_error('Cabin: 当前 source 不是 TileSetAtlasSource')
		_atlasSource = null
		return
	_atlasSource = existingSource as TileSetAtlasSource


## 清空两个 TileMapLayer。
## @return void
func _clear_layers() -> void:
	_visualLayer.clear()


## 将 TileMapLayer 的局部原点平移到舱体中心。
## @return void
func _update_layer_anchor_to_center() -> void:
	if _visualLayer == null:
		return
	var widthPixels: float = float(_grid_cols() * tile_size)
	var heightPixels: float = float(_grid_rows() * tile_size)
	var visualAnchor: Vector2 = Vector2(-widthPixels * 0.5, -heightPixels * 0.5)
	_visualLayer.position = visualAnchor

	var decorOffset: Vector2 = Vector2(
		(widthPixels - INTERIOR_DECOR_WIDTH) * 0.5,
		(heightPixels - INTERIOR_DECOR_HEIGHT) * 0.5
	)
	var decorAnchor: Vector2 = visualAnchor + decorOffset
	var blockAnchor: Vector2 = visualAnchor + Vector2(0.0, float(tile_size))
	_set_layer_position('Visuals/floor', decorAnchor)
	_set_layer_position('Visuals/back', decorAnchor)
	_set_layer_position('Visuals/back_wall', decorAnchor)
	_set_layer_position('Visuals/block', blockAnchor)



## 设置指定子层位置（存在时才更新）。
## @param nodePath 节点路径
## @param anchor 锚点坐标
## @return void
func _set_layer_position(nodePath: String, anchor: Vector2) -> void:
	var layer: Node = get_node_or_null(nodePath)
	if layer is Node2D:
		(layer as Node2D).position = anchor


## 生成基础边界单元（四边框），默认全是实体。
## @param wallCells 视觉单元集合
## @return void
func _fill_boundary_cells(wallCells: Dictionary) -> void:
	var cols: int = _grid_cols()
	var rows: int = _grid_rows()
	var thickness: int = _thickness_cells()

	for y in range(rows):
		for x in range(thickness):
			_add_cell(wallCells, Vector2i(x, y))
		for x in range(cols - thickness, cols):
			_add_cell(wallCells, Vector2i(x, y))

	for y in range(rows - thickness, rows):
		for x in range(cols):
			_add_cell(wallCells, Vector2i(x, y))

	for y in range(0, thickness):
		for x in range(cols):
			_add_cell(wallCells, Vector2i(x, y))


## 应用左右墙门洞挖空规则。
## @param wallCells 视觉单元集合
## @return void
func _apply_door_openings(wallCells: Dictionary) -> void:
	var cols: int = _grid_cols()
	var rows: int = _grid_rows()
	var thickness: int = _thickness_cells()
	var doorCells: int = clampi(int(round(_doorHeight / float(tile_size))), 0, rows)
	var openStartY: int = rows - doorCells

	var ownsLeftWall: bool = true
	var ownsRightWall: bool = true

	if not ownsLeftWall:
		for y in range(rows):
			for x in range(thickness):
				_remove_cell(wallCells, Vector2i(x, y))
	elif _leftDoorOpen:
		for y in range(openStartY, rows):
			for x in range(thickness):
				_remove_cell(wallCells, Vector2i(x, y))

	if not ownsRightWall:
		for y in range(rows):
			for x in range(cols - thickness, cols):
				_remove_cell(wallCells, Vector2i(x, y))
	elif _rightDoorOpen:
		for y in range(openStartY, rows):
			for x in range(cols - thickness, cols):
				_remove_cell(wallCells, Vector2i(x, y))


## 应用地板洞（视觉与碰撞同步留空）。
## @param wallCells 视觉单元集合
## @return void
func _apply_floor_hole(wallCells: Dictionary) -> void:
	if _floorHoleSize <= 0.0:
		return

	var cols: int = _grid_cols()
	var rows: int = _grid_rows()
	var thickness: int = _thickness_cells()
	var innerLeft: int = thickness
	var innerRight: int = cols - thickness
	if innerRight <= innerLeft:
		return

	var holeStart: int = clampi(innerLeft + int(round(_floorHolePosition / float(tile_size))), innerLeft, innerRight)
	var holeWidth: int = max(1, int(round(_floorHoleSize / float(tile_size))))
	var holeEnd: int = clampi(holeStart + holeWidth, innerLeft, innerRight)

	for y in range(rows - thickness, rows):
		for x in range(holeStart, holeEnd):
			_remove_cell(wallCells, Vector2i(x, y))


## 应用天花板洞（仅影响天花板，不影响地板洞）。
## @param wallCells 视觉单元集合
## @return void
func _apply_ceiling_hole(wallCells: Dictionary) -> void:
	if not _renderCeiling:
		return
	if _ceilingHoleSize <= 0.0:
		return

	var cols: int = _grid_cols()
	var thickness: int = _thickness_cells()
	var innerLeft: int = thickness
	var innerRight: int = cols - thickness
	if innerRight <= innerLeft:
		return

	var holeStart: int = clampi(innerLeft + int(round(_ceilingHolePosition / float(tile_size))), innerLeft, innerRight)
	var holeWidth: int = max(1, int(round(_ceilingHoleSize / float(tile_size))))
	var holeEnd: int = clampi(holeStart + holeWidth, innerLeft, innerRight)

	for y in range(0, thickness):
		for x in range(holeStart, holeEnd):
			_remove_cell(wallCells, Vector2i(x, y))


## 应用天花板渲染开关：关闭时隐藏本舱天花板视觉。
## @param wallCells 视觉单元集合
## @return void
func _apply_ceiling_ownership(wallCells: Dictionary) -> void:
	if _renderCeiling:
		return
	var cols: int = _grid_cols()
	var thickness: int = _thickness_cells()
	for y in range(0, thickness):
		for x in range(cols):
			_remove_cell(wallCells, Vector2i(x, y))


## 应用四角渲染开关。
## @param wallCells 视觉单元集合
## @return void
func _apply_corner_toggles(wallCells: Dictionary) -> void:
	var cols: int = _grid_cols()
	var rows: int = _grid_rows()
	var thickness: int = _thickness_cells()

	if not _renderCornerNw:
		for y in range(0, thickness):
			for x in range(0, thickness):
				_remove_cell(wallCells, Vector2i(x, y))

	if not _renderCornerNe:
		for y in range(0, thickness):
			for x in range(cols - thickness, cols):
				_remove_cell(wallCells, Vector2i(x, y))

	if not _renderCornerSw:
		for y in range(rows - thickness, rows):
			for x in range(0, thickness):
				_remove_cell(wallCells, Vector2i(x, y))

	if not _renderCornerSe:
		for y in range(rows - thickness, rows):
			for x in range(cols - thickness, cols):
				_remove_cell(wallCells, Vector2i(x, y))


## 根据连接位掩码绘制视觉 tile。
## @param wallCells 视觉单元集合
## @return void
func _draw_visual_cells(wallCells: Dictionary) -> void:
	for key in wallCells.keys():
		var cell: Vector2i = key
		var mask: int = _neighbor_mask(cell, wallCells)
		var atlas: Vector2i = _atlas_for_mask(cell, mask)
		_visualLayer.set_cell(cell, _sourceId, atlas, 0)


## 获取单元四邻接位掩码。
## @param cell 目标单元
## @param cells 单元集合
## @return int 位掩码（N=1,E=2,S=4,W=8）
func _neighbor_mask(cell: Vector2i, cells: Dictionary) -> int:
	var mask: int = 0
	if cells.has(cell + Vector2i(0, -1)):
		mask |= MASK_N
	if cells.has(cell + Vector2i(1, 0)):
		mask |= MASK_E
	if cells.has(cell + Vector2i(0, 1)):
		mask |= MASK_S
	if cells.has(cell + Vector2i(-1, 0)):
		mask |= MASK_W
	return mask


## 位掩码映射到 atlas 坐标（仅使用四角+四方向边）。
## @param cell 当前单元坐标
## @param mask 邻接位掩码
## @return Vector2i 图块坐标
func _atlas_for_mask(cell: Vector2i, mask: int) -> Vector2i:
	var cols: int = _grid_cols()
	var rows: int = _grid_rows()
	var thickness: int = _thickness_cells()
	var onLeft: bool = cell.x < thickness
	var onRight: bool = cell.x >= cols - thickness
	var onTop: bool = cell.y < thickness
	var onBottom: bool = cell.y >= rows - thickness

	# 先按边界位置稳定判定，避免大面积误判为角块。
	if onTop and onLeft:
		return tile_corner_nw
	if onTop and onRight:
		return tile_corner_ne
	if onBottom and onLeft:
		return tile_corner_sw
	if onBottom and onRight:
		return tile_corner_se
	if onTop:
		return tile_end_n
	if onBottom:
		return tile_end_s
	if onLeft:
		return tile_end_w
	if onRight:
		return tile_end_e

	# 兜底：异常/碎片单元按邻接掩码回退。
	match mask:
		MASK_N | MASK_E:
			return tile_corner_ne
		MASK_N | MASK_W:
			return tile_corner_nw
		MASK_S | MASK_E:
			return tile_corner_se
		MASK_S | MASK_W:
			return tile_corner_sw
		MASK_E | MASK_W:
			return tile_end_n
		MASK_N | MASK_S:
			return tile_end_w
		MASK_N:
			return tile_end_n
		MASK_S:
			return tile_end_s
		MASK_E:
			return tile_end_e
		MASK_W:
			return tile_end_w
		_:
			return tile_end_n


## 计算网格列数。
## @return int 列数
func _grid_cols() -> int:
	return max(2, int(round(_cabinWidth / float(tile_size))))


## 计算网格行数。
## @return int 行数
func _grid_rows() -> int:
	return max(2, int(round(_cabinHeight / float(tile_size))))


## 计算厚度对应的网格层数（固定 1 格）。
## @return int 厚度单元数
func _thickness_cells() -> int:
	return 1


## 向集合加入单元。
## @param cells 单元集合
## @param cell 单元坐标
## @return void
func _add_cell(cells: Dictionary, cell: Vector2i) -> void:
	cells[cell] = true


## 从集合移除单元。
## @param cells 单元集合
## @param cell 单元坐标
## @return void
func _remove_cell(cells: Dictionary, cell: Vector2i) -> void:
	if cells.has(cell):
		cells.erase(cell)


## 检查 atlas 坐标是否在纹理网格范围内。
## @param coords 图块 atlas 坐标
## @return bool 坐标是否合法
func _is_valid_atlas_coords(coords: Vector2i) -> bool:
	if _atlasSource == null:
		return false
	var grid: Vector2i = _atlasSource.get_atlas_grid_size()
	if coords.x < 0 or coords.y < 0:
		return false
	if coords.x >= grid.x or coords.y >= grid.y:
		return false
	return true
