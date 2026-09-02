class_name Lodging
extends RefCounted
## 침대 수 계산. 객실(kind=lodging)의 capacity 합이 침대 수이고, 하숙생 + 체류 중 손님이 하나씩 쓴다.
## "방이 없으면 못 받는다" (docs/00 4절) 규칙의 근거.


static func total_beds(grid: RoomGrid) -> int:
	var beds := 0
	for cell in grid.get_built_cells():
		var room := grid.get_room(cell)
		if room != null and room.kind == "lodging":
			beds += room.capacity
	return beds


static func used_beds(residents: Array[String], guests: Array) -> int:
	return residents.size() + guests.size()


static func free_beds(grid: RoomGrid, residents: Array[String], guests: Array) -> int:
	return total_beds(grid) - used_beds(residents, guests)
