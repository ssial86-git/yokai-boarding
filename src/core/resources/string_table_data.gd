class_name StringTableData
extends Resource
## UI 문자열 테이블. data/csv/strings_ko.csv 전체 = 이 리소스 하나.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다.

## key -> 문자열. {name} 형태 자리표시자는 String.format 으로 채운다.
@export var values: Dictionary = {}


func get_text(key: String) -> String:
	# 키 누락은 눈에 띄게 [key] 로 표시해 CSV 누락을 바로 알아채게 한다.
	return str(values.get(key, "[%s]" % key))
