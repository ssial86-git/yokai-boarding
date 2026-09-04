class_name ArtAssetData
extends Resource
## 아트 매니페스트 한 행 (data/csv/art_assets.csv). 논리 키 → 파일·프레임 규격·애니메이션 구간. ArtLibrary 가 읽는다.
## build_resources.py 가 생성한다. 손으로 편집하지 않는다. 행 추가·교체는 tools/art/studio (웹 Asset Studio) 또는 CSV 직접.

## 논리 키: char.<yokai_id> / char.player / guest.<species_id> / enemy.<enemy_id> / npc.<spirit_id> / room.<room_id>
##          / illust.<id> / region.<region_id>.<sky|far|ground> / prop.<gather_point|farm_plot|door|water|merchant> / ui.<panel|chip|button>
@export var id: String = ""
## pixel / illust / ui
@export var track: String = "pixel"
## res:// 경로
@export var file: String = ""
## 시트 프레임 크기 (0 = 이미지 전체가 한 프레임)
@export var frame_w: int = 0
@export var frame_h: int = 0
## "name:first-last:fps;..." (프레임 번호는 시트를 왼쪽 위부터 가로로 셈). 비면 정지 그림
@export var anims: String = ""
## 배경 레이어 시차 계수 (0 = 카메라와 무관 고정, 1 = 바닥과 같이 움직임)
@export var parallax: float = 1.0
## 가로 반복 여부 (배경·바닥 띠)
@export var repeat: bool = false
@export var note: String = ""
