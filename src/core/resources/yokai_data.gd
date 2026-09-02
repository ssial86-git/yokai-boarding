class_name YokaiData
extends Resource
## 장기 하숙생 1명의 정적 데이터. data/csv/yokai.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
@export var name_ko: String = ""
@export var species_ko: String = ""
## rooms.csv 의 id. 이 방에 배치되면 work_bonus 가 적용된다.
@export var preferred_room: String = ""
@export var work_bonus: float = 0.0
## 0(무음)~3(옆방 수면 방해). 배치 퍼즐 제약.
@export var noise: int = 0
@export var night_worker: bool = false
## money / items / errand / none
@export var rent_type: String = "none"
@export var rent_note_ko: String = ""
@export var stat_strength: int = 0
@export var stat_skill: int = 0
@export var stat_sight: int = 0
@export var stat_courage: int = 0
## 32 또는 16. 스프라이트 규격(px).
@export var sprite_size: int = 32
@export var in_slice: bool = false
