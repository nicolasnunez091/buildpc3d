extends SceneTree

const MAIN = preload("res://scenes/Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mode = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "empty"
	if mode == "empty":
		print("DIAGNÓSTICO: sin instanciar Main")
	elif mode in ["viewer", "viewer_nosky"]:
		var viewer = preload("res://scripts/view/PCViewer.gd").new()
		root.add_child(viewer)
		if mode == "viewer_nosky":
			for node in viewer._scene.get_children():
				if node is WorldEnvironment:
					node.environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG
					node.environment.sky = null
		await process_frame
		viewer.queue_free()
		for i in range(10):
			await process_frame
		print("DIAGNÓSTICO: solo visor")
	elif mode in ["viewport", "sky"]:
		var viewport = SubViewport.new()
		viewport.size = Vector2i(840, 720)
		viewport.own_world_3d = true
		root.add_child(viewport)
		if mode == "sky":
			var world = WorldEnvironment.new()
			var env = Environment.new()
			env.background_mode = Environment.BG_COLOR
			var sky = Sky.new()
			sky.sky_material = ProceduralSkyMaterial.new()
			env.sky = sky
			env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
			world.environment = env
			viewport.add_child(world)
		await process_frame
		viewport.queue_free()
		for i in range(10):
			await process_frame
		print("DIAGNÓSTICO: solo SubViewport")
	else:
		var app = MAIN.instantiate()
		root.add_child(app)
		app._dao._project_id = ""
		await process_frame
		if mode == "assembly":
			app._choose_manual_use("juegos")
			app._generate()
			print("DIAGNÓSTICO: equipo generado = ", not app._equipment.is_empty())
		else:
			print("DIAGNÓSTICO: Main sin generar equipo")
		app.queue_free()
		for i in range(10):
			await process_frame
	await RenderingServer.frame_post_draw
	quit()
