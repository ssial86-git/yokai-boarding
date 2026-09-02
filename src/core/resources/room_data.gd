class_name RoomData
extends Resource
## 방 종류. data/csv/rooms.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
## lodging / production / service / gate / storage / empty
@export var kind: String = "empty"
@export var build_cost: int = 0
## 동시에 들어갈 수 있는 요괴 수(객실은 거주, 시설은 근무 슬롯).
@export var capacity: int = 0
## 시설 담당 가택신 id (spirits.csv, M3). 없으면 빈 문자열.
@export var spirit_id: String = ""
## 소음에 민감한 방(객실 등). 옆방 noise 페널티 대상.
@export var quiet: bool = false
## 이 방을 지으려면 먼저 있어야 하는 방 id. 빈 문자열이면 조건 없음.
@export var requires_room: String = ""
## 낮 가동 산출 아이템 id (items.csv). 빈 문자열이면 산출 없음.
@export var output_item: String = ""
## 일꾼 1명이 하루에 만드는 기본 수량.
@export var output_amount: int = 0
