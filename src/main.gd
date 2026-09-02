extends Node2D
## 메인 씬 루트. M0에서는 autoload가 준비됐는지 확인하는 것 외의 동작이 없다.
## 방 그리드 렌더링·증축 UI는 M1에서 src/house/ 로 코드 조립한다.


func _ready() -> void:
	Events.game_started.emit()
