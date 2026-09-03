class_name MetricsEventData
extends Resource
## 내장 지표 이벤트 정의 (docs/08 7절 게이트 계측). data/csv/metrics_events.csv 한 행 = 이 리소스 하나.
## Metrics autoload 는 여기 정의된 kind 만, 여기 적힌 fields 만 JSONL 로 남긴다. build_resources.py 가 생성한다.

@export var id: String = ""
## session / day / house / economy / intake / story / save / verb
@export var category: String = "day"
## data 에 들어갈 수 있는 필드 이름 목록
@export var fields: Array = []
@export var description: String = ""
