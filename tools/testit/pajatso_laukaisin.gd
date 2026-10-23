extends Node
## Pajatson kyljen laukaisin (puoliksi näkyvä kiekko) lepoasennossa, iskun pohjassa ja palaamassa.
## godot --path . --resolution 1280x720 tools/testit/pajatso_laukaisin.tscn -- <kansio>

const PajatsoGame := preload("res://scripts/pajatso_game.gd")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://pajatso_laukaisin"
	DirAccess.make_dir_recursive_absolute(out)
	var g := PajatsoGame.new()
	add_child(g)
	for i in 4:
		await get_tree().process_frame
	g.set_process(false)
	g._coin_state = "ready"
	g._cp = PajatsoGame.LAUNCH
	g._last_power = 1.0
	for st in [["lepo", 0.0], ["isku", 0.15], ["palaa", 0.27]]:
		g._ring_t = st[1]
		g._root.queue_redraw()
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join(st[0] + ".png"))
		print("kuva ", st[0])
	get_tree().quit()
