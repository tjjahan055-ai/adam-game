extends SceneTree
## Headless test runner. Run from the project folder:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exits with code 0 when all tests pass, 1 otherwise.

## A test that crashes stops early without failing a check, so the runner also
## fails when fewer checks ran than expected. Raise this when adding checks.
const MIN_CHECKS := 56

var failures := 0
var passes := 0


func _init() -> void:
	test_rotation()
	test_link_needs_both_sides()
	test_place_rotate_remove()
	test_win_condition()
	test_all_levels_solvable_at_par()
	test_solver_reports_impossible()
	test_save_round_trip()
	if passes + failures < MIN_CHECKS:
		failures += 1
		printerr("FAIL: only %d checks ran, expected at least %d (a test crashed)" % [passes + failures - 1, MIN_CHECKS])
	print("\n%d passed, %d failed" % [passes, failures])
	quit(1 if failures > 0 else 0)


func check(cond: bool, label: String) -> void:
	if cond:
		passes += 1
	else:
		failures += 1
		printerr("FAIL: " + label)


func test_rotation() -> void:
	var b := RouteBoard
	check(b.rotate_sides(b.N, 1) == b.E, "N rotates to E")
	check(b.rotate_sides(b.W, 1) == b.N, "W rotates to N")
	check(b.rotate_sides(b.E | b.W, 1) == (b.N | b.S), "straight turns vertical")
	check(b.rotate_sides(b.N | b.E, 4) == (b.N | b.E), "four turns is identity")


func _tiny() -> RouteBoard:
	return LevelLoader.parse_route({"width": 3, "height": 1, "par": 1,
		"cells": [{"x": 0, "y": 0, "type": "source", "sides": "E"}, {"x": 2, "y": 0, "type": "target"}],
		"inventory": {"straight": 1, "corner": 1}})


func test_link_needs_both_sides() -> void:
	var b := _tiny()
	check(b != null, "tiny board parses")
	if b == null:
		return
	b.place(Vector2i(1, 0), "corner", 0)  # N|E: no west side, so no link from the source
	check(not b.is_solved(), "corner facing away does not carry power")
	check(b.powered_target_count() == 0, "no target powered")


func test_place_rotate_remove() -> void:
	var b := _tiny()
	if b == null:
		check(false, "tiny board parses")
		return
	check(b.place(Vector2i(1, 0), "straight", 1), "can place on empty cell")
	check(b.inventory["straight"] == 0, "inventory goes down")
	check(not b.place(Vector2i(1, 0), "corner"), "cannot place on occupied cell")
	check(not b.place(Vector2i(0, 0), "corner"), "cannot place on the source")
	check(not b.rotate_at(Vector2i(0, 0)), "cannot rotate a fixed tile")
	check(not b.is_solved(), "vertical straight does not connect")
	b.rotate_at(Vector2i(1, 0))
	check(b.is_solved(), "rotated straight connects")
	check(b.remove_at(Vector2i(1, 0)), "can take piece back")
	check(b.inventory["straight"] == 1, "inventory restored")
	check(not b.remove_at(Vector2i(2, 0)), "cannot remove the target")


func test_win_condition() -> void:
	var b := LevelLoader.load_route("r03")
	check(b != null, "r03 loads")
	if b == null:
		return
	check(b.targets().size() == 2, "r03 has two targets")
	check(not b.is_solved(), "empty board is not solved")


func test_all_levels_solvable_at_par() -> void:
	for id in LevelLoader.route_level_ids():
		var b := LevelLoader.load_route(id)
		check(b != null, id + " loads")
		if b == null:
			continue
		var sol = RouteSolver.solve(b)
		check(sol != null, id + " has a solution")
		if sol == null:
			continue
		check(sol.size() == b.par, "%s par is %d, shortest solution uses %d" % [id, b.par, sol.size()])
		var replay := b.duplicate_board()
		for m in sol:
			var placed := false
			for turns in range(4):
				if RouteBoard.rotate_sides(RouteBoard.PIECE_SIDES[m.piece], turns) == m.sides:
					placed = replay.place(m.pos, m.piece, turns)
					break
			check(placed, id + " solution move is legal")
		check(replay.is_solved(), id + " solution replays to a win")


func test_solver_reports_impossible() -> void:
	var b := LevelLoader.parse_route({"width": 3, "height": 1, "par": 1,
		"cells": [{"x": 0, "y": 0, "type": "source", "sides": "E"}, {"x": 2, "y": 0, "type": "target"}],
		"inventory": {"corner": 1}})
	check(b != null, "impossible board parses")
	if b == null:
		return
	check(RouteSolver.solve(b) == null, "impossible level is reported as unsolvable")


func test_save_round_trip() -> void:
	var save := preload("res://scripts/core/save_game.gd").new()
	save.save_path = "user://test_save.json"
	save.backup_path = "user://test_save.bak"
	save.reset()
	save.record_result("r01", 2)
	save.record_result("r01", 1)  # a worse result must not lower the best
	var again := preload("res://scripts/core/save_game.gd").new()
	again.save_path = save.save_path
	again.backup_path = save.backup_path
	again.load_game()
	check(again.stars_for("r01") == 2, "best stars survive save and load")
	check(again.is_unlocked("r02"), "next level opens after a win")
	check(not again.is_unlocked("r03"), "level after next stays closed")
	save.free()
	again.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.bak"))
