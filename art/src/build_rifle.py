"""Pipe Hitters original rifle ("Line Carbine"), ~0.92 m, built procedurally in Blender.

Run:  /opt/blender/blender -b -P art/src/build_rifle.py
Out:  art/src/rifle.blend and art/models/rifle.glb
Godot coords (x = left, y = up, z = forward/muzzle). Origin = trigger-hand grip point.
Markers (empties): grip, support, muzzle, butt.
"""
import bpy, bmesh, math, os
from mathutils import Vector, Euler

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def G(x, y, z):
    return Vector((x, -z, y))


def mat(name, col, rough, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*col, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*col, 1.0)
    return m


PARTS = []


def box(c, size, m, bevel=0.006, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=G(*c))
    o = bpy.context.active_object
    o.scale = (size[0], size[2], size[1])
    o.rotation_euler = Euler((rot[0], rot[2], rot[1]))  # godot x-rot -> blender
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0:
        b = o.modifiers.new("b", "BEVEL")
        b.width = bevel
        b.segments = 2
        bpy.ops.object.modifier_apply(modifier="b")
    o.data.materials.append(m)
    PARTS.append(o)
    return o


def cyl(c, r, length, m, verts=16, r2=None):
    """Cylinder along +Z (godot forward), centered at c."""
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=length, location=G(*c))
    o = bpy.context.active_object
    o.rotation_euler = (math.pi / 2, 0, 0)  # blender Z -> -Y (godot +Z)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    b = o.modifiers.new("b", "BEVEL")
    b.width = min(0.003, r * 0.3)
    b.segments = 1
    bpy.ops.object.modifier_apply(modifier="b")
    o.data.materials.append(m)
    PARTS.append(o)
    return o


def marker(name, c):
    e = bpy.data.objects.new(name, None)
    e.location = G(*c)
    e.empty_display_size = 0.03
    bpy.context.collection.objects.link(e)
    return e


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    metal = mat("rifle_metal", (0.09, 0.095, 0.1), 0.42, 0.6)
    poly = mat("rifle_polymer", (0.13, 0.13, 0.12), 0.7)
    glass = mat("optic_glass", (0.05, 0.12, 0.14), 0.1, 0.2)
    # Receiver (upper + lower) and top rail.
    box((0, 0.045, 0.05), (0.05, 0.06, 0.27), metal)
    box((0, 0.0, 0.04), (0.046, 0.05, 0.2), metal)
    box((0, 0.082, 0.07), (0.03, 0.014, 0.32), metal, 0.003)
    # Pistol grip (raked back) and trigger guard.
    box((0, -0.055, -0.012), (0.034, 0.11, 0.045), poly, 0.01, rot=(math.radians(18), 0, 0))
    box((0, -0.03, 0.045), (0.012, 0.012, 0.07), metal, 0.003)
    # Magazine: two raked segments for a gentle curve.
    box((0, -0.06, 0.095), (0.026, 0.11, 0.07), poly, 0.006, rot=(math.radians(-8), 0, 0))
    box((0, -0.148, 0.122), (0.026, 0.08, 0.068), poly, 0.006, rot=(math.radians(-20), 0, 0))
    # Buffer tube + adjustable-style stock and butt pad.
    cyl((0, 0.035, -0.145), 0.016, 0.13, metal)
    box((0, 0.02, -0.235), (0.046, 0.1, 0.13), poly, 0.012)
    box((0, 0.05, -0.215), (0.04, 0.03, 0.11), poly, 0.008)
    box((0, 0.015, -0.307), (0.05, 0.13, 0.024), poly, 0.008)
    # Handguard (rounded, slightly larger than the receiver) with a lower rail.
    cyl((0, 0.045, 0.3), 0.03, 0.22, poly, verts=10)
    box((0, 0.012, 0.3), (0.02, 0.012, 0.2), metal, 0.003)
    # Barrel + muzzle device.
    cyl((0, 0.045, 0.475), 0.0095, 0.13, metal)
    cyl((0, 0.045, 0.555), 0.016, 0.05, metal, verts=12)
    # Simple optic: mount + tube with lens ends.
    box((0, 0.1, 0.07), (0.026, 0.024, 0.06), metal, 0.004)
    cyl((0, 0.13, 0.07), 0.02, 0.12, metal)
    cyl((0, 0.13, 0.135), 0.022, 0.012, glass)
    cyl((0, 0.13, 0.005), 0.018, 0.01, glass)
    # Charging handle / ejection port details.
    box((-0.026, 0.05, 0.06), (0.004, 0.02, 0.05), metal, 0.001)
    bpy.ops.object.select_all(action="DESELECT")
    for o in PARTS:
        o.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    rifle = bpy.context.active_object
    rifle.name = "Rifle"
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    rifle.data.name = "RifleMesh"
    for p in rifle.data.polygons:
        p.use_smooth = False
    marks = [marker("grip", (0, -0.04, 0.0)), marker("support", (0, 0.005, 0.24)),
             marker("muzzle", (0, 0.045, 0.58)), marker("butt", (0, 0.02, -0.32))]
    for e in marks:
        e.parent = rifle
    tris = sum(len(p.vertices) - 2 for p in rifle.data.polygons)
    xs = [(rifle.matrix_world @ v.co).y for v in rifle.data.vertices]
    print("RIFLE tris:", tris, "length:", round(max(xs) - min(xs), 3))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "src", "rifle.blend"))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT, "art", "models", "rifle.glb"), export_format="GLB",
                              use_selection=True, export_yup=True, export_texcoords=False, export_apply=True)
    print("EXPORTED", os.path.getsize(os.path.join(ROOT, "art", "models", "rifle.glb")))


main()
