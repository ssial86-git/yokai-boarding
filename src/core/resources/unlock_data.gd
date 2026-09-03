class_name UnlockData
extends Resource
## 해금 일정 (docs/08 재미 원칙 6 케이던스). data/csv/unlocks.csv 한 행 = 이 리소스 하나.
## 시뮬레이터(tools/sim)가 이 표로 "처음 보는 것 없는 30분"이 없는지 검사한다. build_resources.py 가 생성한다.

@export var id: String = ""
## 이 날부터 조건을 평가한다
@export var day_min: int = 1
## 케이던스 검증에서 "이 날엔 열려 있어야 한다"고 보는 날
@export var expected_day: int = 1
## morning / day / evening / night / any
@export var timeband: String = "any"
## 세미콜론 AND 목록: flag:<name> / affinity:<yokai_id>>=<n> / unlock:<unlock_id> / resident:<yokai_id> / item:<item_id>>=<n>
@export var condition: String = ""
## region / tool / talisman / enemy / yokai / event / crop / material / fish / verb / feature
@export var unlock_type: String = "feature"
@export var unlock_id: String = ""
## 열릴 때 성주 영감이 알려주는 문구
@export var hint_ko: String = ""
