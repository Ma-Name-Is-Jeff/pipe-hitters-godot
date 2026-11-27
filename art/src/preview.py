"""Workbench preview renders of a .blend: blender -b art/src/soldier.blend -P art/src/preview.py -- out_prefix"""
import bpy, sys, math
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1]
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.render.resolution_x, sc.render.resolution_y = 700, 900
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_cavity = True
cam_d = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
cam_d.lens = 50
tgt = Vector((0, 0, 0.95))
for name, pos in (("front34", (1.7, -2.9, 1.4)), ("side", (3.3, 0, 1.0)), ("back", (-1.2, 3.2, 1.3)), ("top", (0.01, -1.2, 4.2))):
    cam.location = pos
    cam.rotation_euler = (tgt - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)
