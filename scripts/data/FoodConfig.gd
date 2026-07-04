class_name FoodConfig
extends RefCounted

## 食物配置：定义食物类型、图集区域、价格与加工映射。

enum FoodType {
	RAW_FISH,
	FRIED_FISH,
	BOILED_FISH,
	SASHIMI,
	APPLE,
	PEACH,
	PEAR,
	APPLE_JAM,
	PEACH_JAM,
	PEAR_JAM
}

const FOOD_ATLAS_DISH: Texture2D = ResPath.TEXTURES.DISH_ATLAS
const FOOD_ATLAS_FRUIT: Texture2D = ResPath.TEXTURES.FRUIT_ATLAS
const FOOD_ATLAS_JAM: Texture2D = ResPath.TEXTURES.JAM_ATLAS

## 食物静态数据：价格、图集、区域、标签、分组类型。
## @price 价格（r）
## @atlas 纹理图集
## @region 图集区域
## @tag 交付标签
## @kind 食物大类（fish/fruit/jam）
const FOOD_DATA: Dictionary = {
	FoodType.RAW_FISH: {
		'price': 60,
		'atlas': FOOD_ATLAS_DISH,
		'region': Rect2(0.0, 0.0, 32.0, 29.0),
		'tag': 'raw_fish',
		'kind': 'fish'
	},
	FoodType.FRIED_FISH: {
		'price': 120,
		'atlas': FOOD_ATLAS_DISH,
		'region': Rect2(32.0, 0.0, 32.0, 29.0),
		'tag': 'fried_fish',
		'kind': 'fish'
	},
	FoodType.BOILED_FISH: {
		'price': 120,
		'atlas': FOOD_ATLAS_DISH,
		'region': Rect2(0.0, 29.0, 32.0, 29.0),
		'tag': 'boiled_fish',
		'kind': 'fish'
	},
	FoodType.SASHIMI: {
		'price': 120,
		'atlas': FOOD_ATLAS_DISH,
		'region': Rect2(32.0, 29.0, 32.0, 29.0),
		'tag': 'sashimi',
		'kind': 'fish'
	},
	FoodType.APPLE: {
		'price': 40,
		'atlas': FOOD_ATLAS_FRUIT,
		'region': Rect2(0.0, 0.0, 32.0, 32.0),
		'tag': 'apple',
		'kind': 'fruit'
	},
	FoodType.PEACH: {
		'price': 40,
		'atlas': FOOD_ATLAS_FRUIT,
		'region': Rect2(32.0, 0.0, 32.0, 32.0),
		'tag': 'peach',
		'kind': 'fruit'
	},
	FoodType.PEAR: {
		'price': 40,
		'atlas': FOOD_ATLAS_FRUIT,
		'region': Rect2(64.0, 0.0, 32.0, 32.0),
		'tag': 'pear',
		'kind': 'fruit'
	},
	FoodType.APPLE_JAM: {
		'price': 60,
		'atlas': FOOD_ATLAS_JAM,
		'region': Rect2(0.0, 0.0, 32.0, 32.0),
		'tag': 'apple_jam',
		'kind': 'jam'
	},
	FoodType.PEACH_JAM: {
		'price': 60,
		'atlas': FOOD_ATLAS_JAM,
		'region': Rect2(32.0, 0.0, 32.0, 32.0),
		'tag': 'peach_jam',
		'kind': 'jam'
	},
	FoodType.PEAR_JAM: {
		'price': 60,
		'atlas': FOOD_ATLAS_JAM,
		'region': Rect2(64.0, 0.0, 32.0, 32.0),
		'tag': 'pear_jam',
		'kind': 'jam'
	}
}

## 水果到果酱的加工映射。
const FRUIT_TO_JAM: Dictionary = {
	FoodType.APPLE: FoodType.APPLE_JAM,
	FoodType.PEACH: FoodType.PEACH_JAM,
	FoodType.PEAR: FoodType.PEAR_JAM
}

## 前中后期需求池定义。
const DEMAND_POOL_EARLY: Array[Array] = [
	[FoodType.RAW_FISH]
]

const DEMAND_POOL_MID: Array[Array] = [
	[FoodType.FRIED_FISH],
	[FoodType.BOILED_FISH],
	[FoodType.SASHIMI],
	[FoodType.RAW_FISH, FoodType.APPLE],
	[FoodType.RAW_FISH, FoodType.PEACH],
	[FoodType.RAW_FISH, FoodType.PEAR]
]

const DEMAND_POOL_LATE: Array[Array] = [
	[FoodType.FRIED_FISH, FoodType.APPLE_JAM],
	[FoodType.BOILED_FISH, FoodType.PEACH_JAM],
	[FoodType.SASHIMI, FoodType.PEAR_JAM]
]


## 获取食物价格。
## @param foodType 食物类型
## @return int
static func get_price(foodType: FoodType) -> int:
	var data: Dictionary = FOOD_DATA.get(foodType, {})
	return int(data.get('price', 0))


## 获取食物标签。
## @param foodType 食物类型
## @return String
static func get_tag(foodType: FoodType) -> String:
	var data: Dictionary = FOOD_DATA.get(foodType, {})
	return String(data.get('tag', ''))


## 获取食物类别。
## @param foodType 食物类型
## @return String
static func get_kind(foodType: FoodType) -> String:
	var data: Dictionary = FOOD_DATA.get(foodType, {})
	return String(data.get('kind', ''))


## 构建食物图集纹理。
## @param foodType 食物类型
## @return Texture2D
static func get_atlas_texture(foodType: FoodType) -> Texture2D:
	var data: Dictionary = FOOD_DATA.get(foodType, {})
	var atlasTexture: Texture2D = data.get('atlas', null)
	var region: Rect2 = data.get('region', Rect2())
	if atlasTexture == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = atlasTexture
	texture.region = region
	return texture


## 根据水果类型获取果酱类型。
## @param fruitType 水果类型
## @return int
static func fruit_to_jam(fruitType: FoodType) -> int:
	return int(FRUIT_TO_JAM.get(fruitType, -1))
