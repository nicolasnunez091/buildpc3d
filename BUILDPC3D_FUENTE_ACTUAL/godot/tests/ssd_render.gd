extends SceneTree

const Viewer = preload("res://scripts/view/PCViewer.gd")
const DAO = preload("res://scripts/model/CatalogDAO.gd")
const Rec = preload("res://scripts/model/Recommender.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var dao = DAO.new()
    var catalog = dao._with_local_ssd(JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))["catalog"])
    var team = Rec.new().generar_equipo_inicial("juegos", catalog).equipo
    var viewer = Viewer.new()
    viewer.size = Vector2(840, 720)
    root.add_child(viewer)
    await process_frame
    for index in [0, 1]:
        team.ssd = catalog.ssd[index]
        viewer.enfocar_ssd(false)
        viewer.mostrar_equipo(team)
        for i in range(8): await process_frame
        var assembly_path = ProjectSettings.globalize_path("user://ssd_assembly_%d.png" % index)
        if viewer._viewport.get_texture().get_image().save_png(assembly_path) != OK:
            quit(1)
            return
        print("OK ensamblaje SSD: ", assembly_path)
        viewer.enfocar_ssd(true)
        for i in range(8): await process_frame
        var image = viewer._viewport.get_texture().get_image()
        var path = ProjectSettings.globalize_path("user://ssd_render_%d.png" % index)
        if image.is_empty() or image.save_png(path) != OK:
            printerr("FAIL captura SSD ", index)
            quit(1)
            return
        print("OK captura SSD: ", path)
    viewer.free()
    dao.free()
    quit(0)
