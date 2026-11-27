"""Pipe Hitters soldier: original stylized-realistic figure, built procedurally in Blender.

Run:  /opt/blender/blender -b -P art/src/build_soldier.py
Out:  art/src/soldier.blend  and  art/models/soldier.glb

Coordinates below are written in GODOT space (x = character's left, y = up, z = forward)
and converted with G(). Joint positions match the procedural driver rig in scripts/soldier.gd,
so the game can drive this skeleton straight from the existing animation logic.
"""
import bpy, bmesh, math, os
from mathutils import Vector, Quaternion, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "src")
OUT = os.path.join(ROOT, "art", "models")
TARGET_TRIS = 3600


def G(x, y, z):
    """Godot (x, y-up, z-forward) -> Blender (x, -z, y)."""
    return Vector((x, -z, y))


def gv(v):
    return G(v[0], v[1], v[2])


# ---------------- joints (Godot space; mirror for the right side) ----------------
HIP = (0.0, 0.97, 0.0)
SPINE0 = (0.0, 1.04, 0.0)
SPINE1 = (0.0, 1.17, 0.0)
CHEST = (0.0, 1.30, 0.0)
NECK = (0.0, 1.53, 0.0)
HEAD = (0.0, 1.60, 0.0)
HEAD_TOP = (0.0, 1.86, 0.0)
CLAV = (0.07, 1.50, 0.0)
SHOULDER = (0.285, 1.485, 0.02)
UPPER_LEN, FORE_LEN, HAND_LEN = 0.35, 0.33, 0.17
ARM_DROP = math.radians(42.0)  # A-pose angle from vertical
THIGH = (0.145, 0.92, 0.0)
KNEE = (0.145, 0.48, 0.012)
ANKLE = (0.145, 0.08, 0.0)
BALL = (0.145, 0.025, 0.125)
TOE = (0.145, 0.025, 0.2)


def arm_joints(side):
    s = 1.0 if side == "L" else -1.0
    sh = Vector((SHOULDER[0] * s, SHOULDER[1], SHOULDER[2]))
    d1 = Vector((math.sin(ARM_DROP) * s, -math.cos(ARM_DROP), -0.06)).normalized()
    el = sh + d1 * UPPER_LEN
    d2 = Vector((math.sin(ARM_DROP) * s, -math.cos(ARM_DROP), 0.16)).normalized()
    wr = el + d2 * FORE_LEN
    hd = wr + d2 * HAND_LEN
    return sh, el, wr, hd


def leg_joints(side):
    s = 1.0 if side == "L" else -1.0
    f = lambda p: Vector((p[0] * s, p[1], p[2]))
    return f(THIGH), f(KNEE), f(ANKLE), f(BALL), f(TOE)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------- body: exact primitive volumes -> voxel union -> smooth ----------------
PARTS = []


def _ellipsoid(c, r):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * r[0], v.co.y * r[2], v.co.z * r[1])) + gv(c)
    PARTS.append(bm)


def _capsule(a, b, r0, r1=None):
    r1 = r0 if r1 is None else r1
    a = gv(a); b = gv(b)
    ax = b - a
    ln = ax.length
    q = Vector((0, 0, 1)).rotation_difference(ax.normalized())
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=1.0)
    for v in bm.verts:
        z = v.co.z
        r = r1 if z > 0 else r0
        p = Vector((v.co.x * r, v.co.y * r, z * r + (ln if z > 0 else 0.0)))
        v.co = q @ p + a
    PARTS.append(bm)


def _interp(keys, t):
    """keys: [(t, a, b, c), ...] -> smooth interpolation of the value tuple at t."""
    if t <= keys[0][0]:
        return keys[0][1:]
    for i in range(len(keys) - 1):
        t0, t1 = keys[i][0], keys[i + 1][0]
        if t0 <= t <= t1:
            f = (t - t0) / max(t1 - t0, 1e-6)
            f = f * f * (3 - 2 * f)
            return tuple(keys[i][j] + (keys[i + 1][j] - keys[i][j]) * f for j in range(1, len(keys[i])))
    return keys[-1][1:]


def _loft(a, b, keys, seg=20, rings=16, side_hint=(1, 0, 0)):
    """Smooth tube from a to b (godot coords). keys: (t, rx, rz, off_fwd). Rounded caps."""
    A = Vector(a); B = Vector(b)
    ax = (B - A)
    ln = ax.length
    d = ax.normalized()
    sx = Vector(side_hint)
    sx = (sx - d * sx.dot(d)).normalized()
    sz = d.cross(sx).normalized()
    if sz.z < 0:
        sz = -sz
    bm = bmesh.new()
    prof = []
    r0 = _interp(keys, 0.0); r1 = _interp(keys, 1.0)
    for k in range(6):  # bottom cap
        ph = (math.pi / 2) * k / 6
        prof.append((-math.cos(ph), math.sin(ph), 0.0))
    for k in range(rings + 1):
        prof.append((k / rings, 1.0, k / rings))
    for k in range(1, 7):
        ph = (math.pi / 2) * k / 6
        prof.append((1.0 + math.sin(ph), math.cos(ph), 1.0))
    rows = []
    for (u, sc, t) in prof:
        rx, rz, off = _interp(keys, min(max(t, 0.0), 1.0))
        if u < 0:
            along = u * min(rx, rz) * 0.9
            t_used = 0.0
        elif u > 1:
            along = ln + (u - 1.0) * min(rx, rz) * 0.9
            t_used = 1.0
        else:
            along = u * ln
        c = A + d * along + sz * off
        row = []
        for j in range(seg):
            an = 2 * math.pi * j / seg
            p = c + sx * (math.cos(an) * rx * sc) + sz * (math.sin(an) * rz * sc)
            row.append(bm.verts.new(gv(p)))
        rows.append(row)
    for i in range(len(rows) - 1):
        for j in range(seg):
            bm.faces.new((rows[i][j], rows[i][(j + 1) % seg], rows[i + 1][(j + 1) % seg], rows[i + 1][j]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    PARTS.append(bm)


def build_body():
    PARTS.clear()
    ell = _ellipsoid
    # Torso as one continuous loft (hips -> waist taper -> broad chest -> neck base).
    _loft((0, 0.83, 0), (0, 1.53, 0), [
        (0.0, 0.19, 0.125, -0.01),
        (0.1, 0.235, 0.15, -0.015),
        (0.2, 0.235, 0.15, -0.01),
        (0.3, 0.205, 0.145, -0.005),
        (0.4, 0.195, 0.142, 0.004),
        (0.56, 0.235, 0.155, 0.008),
        (0.72, 0.268, 0.172, 0.006),
        (0.85, 0.268, 0.16, -0.004),
        (0.93, 0.22, 0.125, -0.012),
        (1.0, 0.12, 0.09, -0.01),
    ], seg=28, rings=24, side_hint=(1, 0, 0))
    ell((0, 1.385, 0.06), (0.22, 0.09, 0.1))          # pecs
    for s_ in (1, -1):
        ell((0.085 * s_, 0.905, -0.05), (0.115, 0.11, 0.1))  # glutes
    # Shoulder girdle: ONE continuous yoke (trapezius + both deltoid caps) so there is a single
    # clean shoulder line; the upper arms start with the same radius at the same centre.
    sh_c = SHOULDER[1] - 0.025
    _loft((-SHOULDER[0], sh_c, 0.015), (SHOULDER[0], sh_c, 0.015), [(0, 0.09, 0.1, 0), (1, 0.09, 0.1, 0)], seg=24, rings=14, side_hint=(0, 1, 0))
    for s_ in (1, -1):   # trapezius slope neck -> shoulder
        _loft((0.0, 1.535, -0.012), (0.2 * s_, 1.465, 0.0), [(0, 0.09, 0.075, 0), (1, 0.09, 0.08, 0)], seg=20, rings=10, side_hint=(0, 0, 1))
    _loft((0, 1.44, -0.012), (0, 1.66, 0.0), [(0, 0.108, 0.1, 0), (0.45, 0.088, 0.084, 0), (1, 0.082, 0.08, 0)])   # thick neck
    # Head: skull, brow, face mass, nose, chin, ears. Origin of the head bone stays at (0,1.60,0).
    ell((0, 1.758, -0.004), (0.113, 0.127, 0.122))        # skull
    ell((0, 1.769, 0.092), (0.09, 0.016, 0.03))          # brow ridge
    ell((0, 1.705, 0.03), (0.098, 0.088, 0.09))          # cheeks / jaw (one smooth mass)
    ell((0, 1.66, 0.068), (0.05, 0.03, 0.036))          # chin
    for s_ in (1, -1):
        ell((0.117 * s_, 1.734, -0.008), (0.017, 0.036, 0.025))  # ears
    _capsule((0, 1.752, 0.104), (0, 1.713, 0.126), 0.016, 0.014)   # nose
    for side in ("L", "R"):
        s_ = 1.0 if side == "L" else -1.0
        sh, el, wr, hd = [tuple(v) for v in arm_joints(side)]
        _loft(sh, el, [(0, 0.098, 0.098, 0), (0.4, 0.097, 0.092, 0.004), (1, 0.074, 0.074, 0)])
        _loft(el, wr, [(0, 0.075, 0.075, 0), (0.25, 0.082, 0.076, 0), (1, 0.054, 0.048, 0)])
        d = (Vector(hd) - Vector(wr)).normalized()
        palm = Vector(wr) + d * 0.055
        _loft(tuple(Vector(wr) + d * 0.0), tuple(palm + d * 0.03), [(0, 0.052, 0.035, 0), (1, 0.056, 0.033, 0)])
        _loft(tuple(palm + d * 0.03), tuple(Vector(wr) + d * 0.15), [(0, 0.05, 0.03, 0), (1, 0.04, 0.024, 0)])
        _loft(tuple(Vector(wr) + d * 0.03 + Vector((0, 0, 0.03))), tuple(Vector(wr) + d * 0.09 + Vector((0, 0, 0.06))), [(0, 0.022, 0.022, 0), (1, 0.018, 0.018, 0)])
        _loft(tuple(Vector(wr) - d * 0.035), tuple(Vector(wr) + d * 0.01), [(0, 0.058, 0.057, 0), (1, 0.06, 0.057, 0)])  # glove cuff
        th, kn, an, ba, to = [tuple(v) for v in leg_joints(side)]
        _loft(th, kn, [(0, 0.115, 0.115, 0), (0.3, 0.138, 0.132, 0.008), (0.85, 0.1, 0.098, 0.0), (1, 0.09, 0.09, 0)])
        _loft(kn, an, [(0, 0.09, 0.092, 0.006), (0.28, 0.095, 0.104, -0.018), (0.8, 0.07, 0.072, 0), (1, 0.066, 0.066, 0)])
        _loft((an[0], 0.24, an[2] - 0.005), (an[0], 0.075, an[2]), [(0, 0.082, 0.084, 0), (1, 0.086, 0.088, 0)])   # boot cuff
        _loft((an[0], 0.06, -0.07), (to[0], 0.055, 0.19), [(0, 0.074, 0.066, 0), (0.6, 0.082, 0.066, 0), (1, 0.068, 0.056, 0)], side_hint=(1, 0, 0))  # boot

    bm = bmesh.new()
    me = bpy.data.meshes.new("SoldierMesh")
    for part in PARTS:
        tmp = bpy.data.meshes.new("tmp")
        part.to_mesh(tmp)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    bm.to_mesh(me)
    body = bpy.data.objects.new("Soldier", me)
    bpy.context.collection.objects.link(body)
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    m = body.modifiers.new("Remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = 0.006
    bpy.ops.object.modifier_apply(modifier="Remesh")
    sm = body.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.5
    sm.iterations = 10
    bpy.ops.object.modifier_apply(modifier="Smooth")
    for v in body.data.vertices:   # flat boot soles
        if v.co.z < 0.015:
            v.co.z = max(v.co.z, 0.0) * 0.25
    # Protect the face and shoulder girdle from decimation.
    keep = body.vertex_groups.new(name="keep_detail")
    for v in body.data.vertices:
        g = Vector((v.co.x, v.co.z, -v.co.y))
        if g.y > 1.52 and abs(g.x) < 0.14:
            keep.add([v.index], 0.92, "REPLACE")     # head + neck collar
        elif g.y > 1.36 and abs(g.x) < 0.42:
            keep.add([v.index], 0.45, "REPLACE")     # shoulder girdle
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("PRE-DECIMATE tris", tris)
    dec = body.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, TARGET_TRIS / max(tris, 1))
    dec.vertex_group = "keep_detail"
    dec.invert_vertex_group = True
    dec.vertex_group_factor = 1.0
    bpy.ops.object.modifier_apply(modifier="Decimate")
    body.vertex_groups.remove(body.vertex_groups["keep_detail"])
    for p in body.data.polygons:
        p.use_smooth = True
    return body


def build_hair_eyes():
    """Short buzz-cut hair shell (own material, distinct from the body from above) + dark eyes."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=32, radius=1.0, location=gv((0, 1.758, -0.004)))
    h = bpy.context.active_object
    h.name = "Hair"
    h.scale = (0.12, 0.133, 0.13)  # blender x, y(depth), z(height)
    bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new()
    bm.from_mesh(h.data)
    def smooth(a, b, x):
        t = min(max((x - a) / (b - a), 0.0), 1.0)
        return t * t * (3 - 2 * t)
    clamped = set()
    for v in bm.verts:
        g = Vector((v.co.x, v.co.z, -v.co.y))
        fwd = g.z
        cut = 1.774 + 0.042 * smooth(0.02, 0.085, fwd) - 0.072 * smooth(-0.01, -0.09, fwd)
        cut += 0.01 * (1 - smooth(0.0, 0.08, abs(g.x)))   # slightly lower hairline at the temples
        if g.y < cut:
            v.co.z = cut   # blender z = godot y
            clamped.add(v)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if all(v in clamped for v in f.verts)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(h.data)
    bm.free()
    so = h.modifiers.new("Solid", "SOLIDIFY")
    so.thickness = 0.014
    so.offset = -1.0
    bpy.ops.object.modifier_apply(modifier="Solid")
    for p in h.data.polygons:
        p.use_smooth = True
    # Eyes: small dark ovals on the face.
    eyes = []
    for s_ in (1, -1):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1.0, location=gv((0.045 * s_, 1.752, 0.107)))
        e = bpy.context.active_object
        e.scale = (0.016, 0.009, 0.012)
        bpy.ops.object.transform_apply(scale=True)
        for p in e.data.polygons:
            p.use_smooth = True
        eyes.append(e)
    bpy.ops.object.select_all(action="DESELECT")
    for e in eyes:
        e.select_set(True)
    bpy.context.view_layer.objects.active = eyes[0]
    bpy.ops.object.join()
    return h, eyes[0]


def mat(name, col, rough, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*col, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*col, 1.0)
    m.roughness = rough
    return m


def build_armature():
    arm = bpy.data.armatures.new("SoldierRig")
    ob = bpy.data.objects.new("SoldierRig", arm)
    bpy.context.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones

    def bone(name, a, b, parent=None, connect=False, roll_up=None):
        x = eb.new(name)
        x.head = gv(a)
        x.tail = gv(b)
        if parent:
            x.parent = eb[parent]
            x.use_connect = connect
        if roll_up is not None:
            x.align_roll(gv(roll_up))
        return x

    fwd = (0, 0, 1)
    bone("hips", HIP, SPINE0, roll_up=fwd)
    bone("spine", SPINE0, SPINE1, "hips", True, fwd)
    bone("spine1", SPINE1, CHEST, "spine", True, fwd)
    bone("chest", CHEST, NECK, "spine1", True, fwd)
    bone("neck", NECK, HEAD, "chest", True, fwd)
    bone("head", HEAD, HEAD_TOP, "neck", True, fwd)
    for side in ("L", "R"):
        s = 1.0 if side == "L" else -1.0
        sh, el, wr, hd = arm_joints(side)
        bone("clavicle." + side, (CLAV[0] * s, CLAV[1], CLAV[2]), tuple(sh), "chest", False, (0, 1, 0))
        bone("upper_arm." + side, tuple(sh), tuple(el), "clavicle." + side, True, fwd)
        bone("forearm." + side, tuple(el), tuple(wr), "upper_arm." + side, True, fwd)
        bone("hand." + side, tuple(wr), tuple(hd), "forearm." + side, True, fwd)
        th, kn, an, ba, to = leg_joints(side)
        bone("thigh." + side, tuple(th), tuple(kn), "hips", False, fwd)
        bone("shin." + side, tuple(kn), tuple(an), "thigh." + side, True, fwd)
        bone("foot." + side, tuple(an), tuple(ba), "shin." + side, True, (0, 1, 0))
        bone("toe." + side, tuple(ba), tuple(to), "foot." + side, True, (0, 1, 0))
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def _past_wrist(g):
    for side in ("L", "R"):
        sh, el, wr, hd = arm_joints(side)
        d = (wr - el).normalized()
        if (g - (wr - d * 0.035)).dot(d) > 0 and (g - wr).length < 0.25:
            return True
    return False


def clean_seams(body):
    """Cut clean edge loops where materials change (waist, boot tops, neck, wrists)."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    cuts = [(gv((0, 1.0, 0)), Vector((0, 0, 1))), (gv((0, 0.235, 0)), Vector((0, 0, 1))), (gv((0, 1.60, 0)), Vector((0, 0, 1)))]
    for side in ("L", "R"):
        sh, el, wr, hd = arm_joints(side)
        d = (wr - el).normalized()
        cuts.append((gv(tuple(wr - d * 0.035)), gv(tuple(d)) - gv((0, 0, 0))))
    for co, no in cuts:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no.normalized())
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bm.to_mesh(body.data)
    bm.free()


def smooth_weights(body):
    """Even out the skin weights around neck / shoulders / armpits so the girdle never pinches or doubles."""
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(body.data)
    for v in bm.verts:
        g = Vector((v.co.x, v.co.z, -v.co.y))
        v.select = 1.3 < g.y < 1.66
    bm.select_flush(True)
    bmesh.update_edit_mesh(body.data)
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    body.data.use_paint_mask_vertex = True
    for _ in range(3):
        bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.6, repeat=4, expand=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)


def assign_materials(body, rig):
    M = {
        "top": mat("uniform_top", (0.2, 0.21, 0.22), 0.88),
        "pants": mat("uniform_pants", (0.17, 0.18, 0.19), 0.9),
        "gloves": mat("gloves", (0.1, 0.1, 0.1), 0.65),
        "boots": mat("boots", (0.08, 0.08, 0.08), 0.55),
        "skin": mat("skin", (0.77, 0.63, 0.52), 0.8),
    }
    order = ["top", "pants", "gloves", "boots", "skin"]
    for k in order:
        body.data.materials.append(M[k])
    vg = {g.index: g.name for g in body.vertex_groups}
    me = body.data
    for p in me.polygons:
        c = p.center
        g = Vector((c.x, c.z, -c.y))
        w = {}
        for vi in p.vertices:
            for ge in me.vertices[vi].groups:
                n = vg.get(ge.group, "")
                w[n] = w.get(n, 0.0) + ge.weight
        dom = max(w, key=w.get) if w else ""
        if g.y < 0.235 and abs(g.x) > 0.03:
            k = "boots"
        elif _past_wrist(g):
            k = "gloves"
        elif g.y > 1.60 and abs(g.x) < 0.16:
            k = "skin"
        elif g.y < 1.0 and not dom.startswith(("upper_arm", "forearm", "hand")):
            k = "pants"
        else:
            k = "top"
        p.material_index = order.index(k)
    return M


def main():
    reset()
    body = build_body()
    clean_seams(body)
    rig = build_armature()
    # Automatic weights.
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    smooth_weights(body)
    empty = [v.index for v in body.data.vertices if not v.groups]
    print("verts without weights:", len(empty))
    assign_materials(body, rig)
    hair, eyes = build_hair_eyes()
    hair.data.materials.append(mat("hair", (0.2, 0.12, 0.07), 0.9))
    eyes.data.materials.append(mat("eyes", (0.04, 0.04, 0.045), 0.35))
    for o in (hair, eyes):
        g = o.vertex_groups.new(name="head")
        g.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    hair.select_set(True)
    eyes.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    body.data.validate()
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("SOLDIER tris:", tris, "verts:", len(body.data.vertices))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "soldier.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "soldier.glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_skins=True, export_animations=False, export_apply=False,
                              export_materials="EXPORT", export_texcoords=False, export_normals=True)
    print("EXPORTED", os.path.getsize(os.path.join(OUT, "soldier.glb")))


main()
