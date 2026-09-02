class_name RoomGraph
extends RefCounted
## 방 슬롯 그리드 위의 이동 그래프. 같은 층 옆 칸끼리 연결되고, 계단 열(stair_column)에서만 층을 오르내린다.
## 내비메시 없이 BFS 로 칸 경로를 구한다 (CLAUDE.md 5.7).


static func neighbors(grid: RoomGrid, cell: Vector2i, stair_column: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not grid.is_in_bounds(cell) or not grid.is_floor_built(cell.y):
		return result
	for dx in [-1, 1]:
		var side := cell + Vector2i(dx, 0)
		if grid.is_in_bounds(side):
			result.append(side)
	if cell.x == stair_column:
		for dy in [-1, 1]:
			var vertical := cell + Vector2i(0, dy)
			if grid.is_in_bounds(vertical) and grid.is_floor_built(vertical.y):
				result.append(vertical)
	return result


## from 과 to 를 모두 포함한 최단 칸 경로. 닿을 수 없으면 빈 배열.
static func find_path(grid: RoomGrid, from: Vector2i, to: Vector2i, stair_column: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not grid.is_in_bounds(from) or not grid.is_in_bounds(to):
		return path
	if not grid.is_floor_built(from.y) or not grid.is_floor_built(to.y):
		return path
	if from == to:
		path.append(from)
		return path
	var came_from: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to:
			break
		for next in neighbors(grid, current, stair_column):
			if not came_from.has(next):
				came_from[next] = current
				queue.append(next)
	if not came_from.has(to):
		return path
	var cursor := to
	while cursor != from:
		path.push_front(cursor)
		cursor = came_from[cursor]
	path.push_front(from)
	return path
