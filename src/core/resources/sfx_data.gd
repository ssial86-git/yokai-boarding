class_name SfxData
extends Resource
## 효과음 항목. data/csv/sfx.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
## assets/audio/generated/ 아래 파일명
@export var file: String = ""
@export var volume_db: float = 0.0
@export var loop: bool = false
