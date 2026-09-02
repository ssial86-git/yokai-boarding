class_name VisitorData
extends Resource
## 방문자 유형 (docs/07 리스크 테이블). data/csv/visitors.csv 한 행 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

@export var id: String = ""
## guest / troublemaker / erased
@export var kind: String = "guest"
## 추첨 가중치. 0 이면 무작위 추첨에서 제외(고정 이벤트 전용).
@export var weight: int = 0
@export var omen_min: int = 0
@export var omen_max: int = 0
@export var name_ko: String = ""
## 문돌이의 소개 대사
@export var intro_ko: String = ""
## troublemaker 체크아웃 때 잃는 돈
@export var mishap_money: int = 0
@export var mishap_text_ko: String = ""
