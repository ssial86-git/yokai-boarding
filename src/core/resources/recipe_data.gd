class_name RecipeData
extends Resource
## 요리 레시피 (조왕 부엌 가마솥). data/csv/recipes.csv 한 행 = 이 리소스 하나.
## 산출물은 items.csv 의 food 아이템이며 손님 만족(guest_species.liked_recipe)·동료 버프(buff_*)·판매의 3중 용도를 갖는다.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## 1 / 2 — unlocks.csv feature recipes_tier<n> 으로 열린다
@export var tier: int = 1
@export var output_item: String = ""
@export var output_count: int = 1
## "item_id:n" 목록
@export var ingredients: Array = []
## 실시간 조리 시간(초)
@export var cook_seconds: float = 30.0
## none / strength / skill / sight / courage — 배식하면 그 요괴의 오늘 능력치가 오른다
@export var buff_stat: String = "none"
@export var buff_amount: int = 0
