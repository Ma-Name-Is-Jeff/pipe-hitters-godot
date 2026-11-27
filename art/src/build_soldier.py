"""Pipe Hitters soldier (v1l): CC0 MakeHuman base mesh, customized into our own soldier.

Run:  /opt/blender/blender -b -P art/src/build_soldier.py
In:   art/src/makehuman/base.obj + targets/*.target   (MakeHuman assets, CC0 1.0 - see art/LICENSES.md)
Out:  art/src/soldier.blend and art/models/soldier.glb

Coordinates in GODOT space (x = character's left, y = up, z = forward), metres; G() converts to Blender.
Bone names / chain match the procedural driver in scripts/soldier.gd (22 bones).
"""
import bpy, bmesh, math, os, collections
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "src")
MH = os.path.join(SRC, "makehuman")
OUT = os.path.join(ROOT, "art", "models")
TARGET_TRIS = 5200
HIP_JOINT_Y = 0.92      # driver leg length (thigh joint height)

# Body shaping: MakeHuman macro + local targets (our own mix -> chunky young male soldier).
MUSCLE, WEIGHT = 0.8, 0.88
mw = (MUSCLE - 0.5) * 2.0
ww = (WEIGHT - 0.5) * 2.0
# Balanced, grounded build: no V-taper / trapezoid shapes, natural waist, legs as sturdy as the torso.
TARGETS = {
    "caucasian-male-young": 1 / 3, "african-male-young": 1 / 3, "asian-male-young": 1 / 3,
    "universal-male-young-averagemuscle-averageweight": (1 - mw) * (1 - ww),
    "universal-male-young-maxmuscle-averageweight": mw * (1 - ww),
    "universal-male-young-averagemuscle-maxweight": (1 - mw) * ww,
    "universal-male-young-maxmuscle-maxweight": mw * ww,
    "male-young-maxmuscle-averageweight-idealproportions": 0.3,
    "torso-muscle-pectoral-incr": 0.25, "torso-muscle-dorsi-incr": 0.2,
    "neck-scale-horiz-incr": 0.8, "neck-scale-depth-incr": 0.6,
    "l-upperarm-shoulder-muscle-incr": 0.35, "r-upperarm-shoulder-muscle-incr": 0.35,
    "l-upperarm-muscle-incr": 0.5, "r-upperarm-muscle-incr": 0.5,
    "l-lowerarm-muscle-incr": 0.5, "r-lowerarm-muscle-incr": 0.5,
    "l-upperleg-muscle-incr": 0.9, "r-upperleg-muscle-incr": 0.9,
}
# Cartoony thickness (radial scale about each bone axis) - sturdy limbs, solid torso.
THICK = {"torso": 1.07, "neck": 1.1, "upper_arm": 1.14, "forearm": 1.14, "thigh": 1.16, "shin": 1.18}
ARM_STRETCH = 1.12   # a touch longer arms so the full-size rifle is held with both hands
HAND_SCALE = 1.14


def G(x, y, z):
    return Vector((x, -z, y))


def gv(v):
    return G(v[0], v[1], v[2])


def bg(co):
    """Blender -> Godot."""
    return Vector((co.x, co.z, -co.y))


def load_mh():
    V, groups, faces, g = [], collections.defaultdict(set), collections.defaultdict(list), None
    for l in open(os.path.join(MH, "base.obj")):
        if l.startswith("v "):
            V.append(Vector(tuple(map(float, l.split()[1:4]))))
        elif l.startswith("g "):
            g = l.split()[1]
        elif l.startswith("f "):
            idx = [int(p.split("/")[0]) - 1 for p in l.split()[1:]]
            groups[g].update(idx)
            faces[g].append(idx)
    for name, w in TARGETS.items():
        if abs(w) < 1e-6:
            continue
        for l in open(os.path.join(MH, "targets", name + ".target")):
            if l.startswith("#") or not l.strip():
                continue
            p = l.split()
            V[int(p[0])] += Vector((float(p[1]), float(p[2]), float(p[3]))) * w
    return V, groups, faces


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    V, groups, faces = load_mh()
    J = {n[6:]: sum((V[i] for i in s), Vector()) / len(s) for n, s in groups.items() if n.startswith("joint-")}
    body_v = groups["body"]
    sole = min(V[i].y for i in body_v)
    s = HIP_JOINT_Y / (J["l-upper-leg"].y - sole)
    T = lambda p: Vector((p.x * s, (p.y - sole) * s, p.z * s))
    J = {k: T(v) for k, v in J.items()}
    # Straighten the splayed legs (rigid rotation of each leg about its hip joint; ankles under the hips).
    leg_rot = {}
    for sd, sg in (("l", 1), ("r", -1)):
        hip, ank = J[sd + "-upper-leg"], J[sd + "-ankle"]
        want_x = hip.x + sg * 0.03
        ang = math.atan2(ank.x - want_x, hip.y - ank.y)
        leg_rot[sd] = (hip, ang)
    # ---- build body (+ eyeballs) in Godot space ----
    used = sorted(body_v | groups["helper-l-eye"] | groups["helper-r-eye"])
    remap = {old: i for i, old in enumerate(used)}
    P = [T(V[o]) for o in used]
    is_eye = [o not in body_v for o in used]
    # 1) straighten legs (rigid rotation about each hip joint, faded in below the crotch)
    def rot_xy(d, a):
        return Vector((d.x * math.cos(a) + d.y * math.sin(a), -d.x * math.sin(a) + d.y * math.cos(a), d.z))
    for i, g in enumerate(P):
        for sd, sg in (("l", 1), ("r", -1)):
            hip, ang = leg_rot[sd]
            if g.y < hip.y + 0.02 and g.x * sg > 0.0:
                w = min(1.0, max(0.0, (hip.y + 0.02 - g.y) / 0.14)) * min(1.0, max(0.0, g.x * sg / 0.04))
                P[i] = hip + rot_xy(g - hip, ang * w)
    for sd in ("l", "r"):
        hip, ang = leg_rot[sd]
        for k in ("knee", "ankle", "foot-1", "foot-2"):
            J[sd + "-" + k] = hip + rot_xy(J[sd + "-" + k] - hip, ang)
    # Label each vertex by its nearest bone segment (so arm edits never touch the thighs, etc.).
    def segments():
        sg_ = [("torso", Vector((0, J["pelvis"].y - 0.1, J["pelvis"].z)), Vector((0, J["neck"].y, J["neck"].z))),
               ("neck", Vector((0, J["neck"].y, J["neck"].z)), Vector((0, J["head"].y, J["head"].z))),
               ("head", Vector((0, J["head"].y, J["head"].z)), Vector((0, J["head-2"].y, J["head"].z)))]
        for sd in ("l", "r"):
            sg_ += [("upper_arm", J[sd + "-shoulder"], J[sd + "-elbow"]), ("forearm", J[sd + "-elbow"], J[sd + "-hand"]),
                    ("hand", J[sd + "-hand"], J[sd + "-finger-3-4"]),
                    ("thigh", J[sd + "-upper-leg"], J[sd + "-knee"]), ("shin", J[sd + "-knee"], J[sd + "-ankle"] + Vector((0, 0.04, 0))),
                    ("foot", J[sd + "-ankle"], J[sd + "-foot-2"])]
        return sg_
    def nearest(g, sg_):
        best, bc, bn, bs = 1e9, None, None, None
        for name, a_, b_ in sg_:
            ab = b_ - a_
            t = max(0.0, min(1.0, (g - a_).dot(ab) / ab.length_squared))
            c = a_ + ab * t
            dist = (g - c).length
            if dist < best:
                best, bc, bn, bs = dist, c, name, ("l" if a_.x > 0.01 else "r" if a_.x < -0.01 else "")
        return bn, bs, bc
    SEG = segments()
    LAB = [nearest(g, SEG)[:2] for g in P]
    # 2) arms a bit longer (stretch along the bones only, thickness unchanged)
    fingers = [k for k in J if "-finger-" in k or "-hand" in k]
    for sd, sg in (("l", 1), ("r", -1)):
        sh, el, wr = J[sd + "-shoulder"].copy(), J[sd + "-elbow"].copy(), J[sd + "-hand"].copy()
        d1, d2 = (el - sh).normalized(), (wr - el).normalized()
        L1, L2 = (el - sh).length, (wr - el).length
        def stretch(g):
            t1 = (g - sh).dot(d1)
            w = min(1.0, max(0.0, (t1 + 0.02) / 0.06))
            off = d1 * (ARM_STRETCH - 1) * min(max(t1, 0.0), L1) * w
            t2 = (g - el).dot(d2)
            if t1 > L1 * 0.7:
                off += d2 * (ARM_STRETCH - 1) * min(max(t2, 0.0), L2) * min(1.0, max(0.0, (t1 - L1 * 0.7) / (L1 * 0.3)))
            return g + off
        for i, g in enumerate(P):
            if not is_eye[i] and LAB[i][0] in ("upper_arm", "forearm", "hand") and LAB[i][1] == sd:
                P[i] = stretch(g)
        for f in fingers:
            if f.startswith(sd + "-"):
                J[f] = stretch(J[f])
        J[sd + "-elbow"] = el + d1 * (ARM_STRETCH - 1) * L1
    # 3) hands are replaced later with clean procedural gloves (no MH thumb spikes).
    # 4) cartoony thickness: scale radially about the nearest bone axis
    SEG = [x for x in segments()]
    for i, g in enumerate(P):
        if is_eye[i] or g.y > J["head"].y + 0.02:
            continue
        bk, _, bc = nearest(g, SEG)
        if bk not in THICK:
            continue
        k = THICK[bk]
        if bk == "torso":   # torso: widen in x/z only around the spine line, waist stays natural
            P[i] = Vector((bc.x + (g.x - bc.x) * k, g.y, bc.z + (g.z - bc.z) * k))
        elif bk == "neck":
            k = 1.0 + (k - 1.0) * min(1.0, max(0.0, (J["head"].y + 0.02 - g.y) / 0.06))
            P[i] = bc + (g - bc) * k
        else:
            P[i] = bc + (g - bc) * k
    # Slightly larger head (a touch of cartoon), blended in over the upper neck.
    hc = Vector((0, J["head"].y, J["head"].z))
    for i, g in enumerate(P):
        w = min(1.0, max(0.0, (g.y - (J["head"].y - 0.06)) / 0.06))
        if w > 0:
            P[i] = hc + (g - hc) * (1.0 + 0.08 * w)
    for k in ("head-2", "l-eye", "r-eye"):
        J[k] = hc + (J[k] - hc) * 1.08
    bm = bmesh.new()
    verts = [bm.verts.new(gv(p)) for p in P]
    eye_set = set()
    for gname in ("body", "helper-l-eye", "helper-r-eye"):
        for f in faces[gname]:
            try:
                fc = bm.faces.new([verts[remap[i]] for i in f])
            except ValueError:
                continue
            if gname != "body":
                eye_set.add(fc)
    eye_verts = set(v for f in eye_set for v in f.verts)
    # Region thresholds (Godot space).
    wr = {sd: J[sd + "-hand"] for sd in ("l", "r")}
    el = {sd: J[sd + "-elbow"] for sd in ("l", "r")}
    boot_top = 0.235
    waist_y = J["pelvis"].y + 0.075
    collar_y = J["neck"].y - 0.012
    eye_y = (J["l-eye"].y + J["r-eye"].y) * 0.5
    eye_z = J["l-eye"].z
    head_back_z = J["head"].z - 0.11
    hair_front = eye_y + 0.05
    hair_back = J["head"].y - 0.005
    globals().update(dict(BOOT_TOP=boot_top, WAIST_Y=waist_y, COLLAR_Y=collar_y, WR=wr, EL=el, J=J,
                          HAIR=(hair_front, hair_back, eye_z, head_back_z), EYE_Y=eye_y))
    LEG_R = {}
    for sd, sg in (("l", 1), ("r", -1)):
        an = J[sd + "-ankle"]
        rs = [math.hypot(p.x - an.x, p.z - an.z) for i, p in enumerate(P) if not is_eye[i] and 0.2 < p.y < 0.24 and p.x * sg > 0.02]
        LEG_R[sd] = max(rs) if rs else 0.06
    globals()["LEG_R"] = LEG_R
    # 5) drop MH feet and hands — replaced with our own boots and gloves.
    kill = [v for v in bm.verts if v not in eye_verts and bg(v.co).y < 0.13]
    for sd in ("l", "r"):
        d = (WR[sd] - EL[sd]).normalized()
        cut = WR[sd] - d * 0.02
        for v in bm.verts:
            if v in eye_verts:
                continue
            g = bg(v.co)
            if (g - cut).dot(d) > 0 and (g - WR[sd]).length < 0.3:
                kill.append(v)
    bmesh.ops.delete(bm, geom=list(set(kill)), context="VERTS")
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary], sides=0)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.normal_update()
    # 6) clothing volume
    for v in bm.verts:
        if v in eye_verts:
            continue
        g = bg(v.co)
        k = region(g)
        off = {"boots": 0.02, "pants": 0.01, "top": 0.008, "gloves": 0.004, "hair": 0.0045}.get(k, 0.0)
        v.co += v.normal * off
    # flat boot soles
    for v in bm.verts:
        if v.co.z < 0.015:
            v.co.z = max(v.co.z, 0.0) * 0.3
    me = bpy.data.meshes.new("SoldierMesh")
    bm.verts.index_update()
    eye_idx = [v.index for v in eye_verts if v.is_valid]
    bm.to_mesh(me)
    bm.free()
    body = bpy.data.objects.new("Soldier", me)
    bpy.context.collection.objects.link(body)
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    eg = body.vertex_groups.new(name="eyeball")
    eg.add(eye_idx, 1.0, "REPLACE")
    # Decimate, protecting face/neck/shoulders a bit.
    keep = body.vertex_groups.new(name="keep_detail")
    for v in body.data.vertices:
        g = bg(v.co)
        if g.y > J["neck"].y - 0.03 and abs(g.x) < 0.13:
            keep.add([v.index], 0.75, "REPLACE")
        elif g.y > J["l-clavicle"].y - 0.12:
            keep.add([v.index], 0.35, "REPLACE")
        elif 0.35 < g.y < WAIST_Y + 0.02 and abs(g.x) > 0.04:
            keep.add([v.index], 0.4, "REPLACE")   # thighs: less faceting
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.quads_convert_to_tris()
    bpy.ops.object.mode_set(mode="OBJECT")
    tris = len(body.data.polygons)
    print("PRE tris", tris)
    dec = body.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, TARGET_TRIS / tris)
    dec.vertex_group = "keep_detail"
    dec.invert_vertex_group = True
    dec.vertex_group_factor = 1.0
    bpy.ops.object.modifier_apply(modifier="Decimate")
    body.vertex_groups.remove(body.vertex_groups["keep_detail"])
    # Light smooth on the body (not the face) to knock down thigh faceting.
    smg = body.vertex_groups.new(name="smooth_body")
    for v in body.data.vertices:
        g = bg(v.co)
        if g.y < J["neck"].y - 0.04:
            smg.add([v.index], 1.0 if 0.3 < g.y < WAIST_Y + 0.08 else 0.45, "REPLACE")
    sm = body.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.45
    sm.iterations = 5
    sm.vertex_group = "smooth_body"
    bpy.ops.object.modifier_apply(modifier="Smooth")
    body.vertex_groups.remove(body.vertex_groups["smooth_body"])
    extras = [build_boots(LEG_R), build_gloves(), build_kit(body)]
    bpy.ops.object.select_all(action="DESELECT")
    for o in extras:
        o.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    print("PRE-SEAM tris", tris)
    # Do not decimate belt/collar/cuffs/boots/gloves with the body. A joint
    # decimate welds the proud belt into the torso and leaves a jagged
    # shirt/pants bite. If we are over budget, shrink only untagged body verts,
    # and do it BEFORE clean_seams so the waist loop stays a clean cut.
    kit_names = {"is_belt", "is_collar", "is_cuffs", "is_gloves", "is_boots"}
    SEAM_ROOM = 1600
    if tris > 10000 - SEAM_ROOM:
        keep = body.vertex_groups.new(name="keep_kit")
        for v in body.data.vertices:
            if any(body.vertex_groups[ge.group].name in kit_names and ge.weight > 0.4 for ge in v.groups):
                keep.add([v.index], 1.0, "REPLACE")
            else:
                g = bg(v.co)
                if g.y > COLLAR_Y - 0.04:
                    keep.add([v.index], 0.7, "REPLACE")
        d = body.modifiers.new("DecBody", "DECIMATE")
        d.ratio = min(1.0, (8200) / tris)
        d.vertex_group = "keep_kit"
        d.invert_vertex_group = True
        d.vertex_group_factor = 1.0
        bpy.ops.object.modifier_apply(modifier="DecBody")
        if "keep_kit" in [g.name for g in body.vertex_groups]:
            body.vertex_groups.remove(body.vertex_groups["keep_kit"])
        print("POST-DECBODY tris", sum(len(p.vertices) - 2 for p in body.data.polygons))
    clean_seams(body)
    for p in body.data.polygons:
        p.use_smooth = True
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    add_clean_eyes(body)
    # Face materials use is_* groups, which automatic weights will replace, so assign first.
    assign_materials(body, set())
    for g in list(body.vertex_groups):
        body.vertex_groups.remove(g)
    rig = build_armature()
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # Pin the irises to the head bone.
    iris = [v.index for v in body.data.vertices
            if min((bg(v.co) - J["l-eye"]).length, (bg(v.co) - J["r-eye"]).length) < 0.02]
    if "head" in [g.name for g in body.vertex_groups] and iris:
        for g_ in body.vertex_groups:
            if g_.name != "head":
                g_.remove(iris)
        body.vertex_groups["head"].add(iris, 1.0, "REPLACE")
    smooth_weights(body)
    empty = [v.index for v in body.data.vertices if not v.groups]
    print("verts without weights:", len(empty), "of", len(body.data.vertices))
    if empty:
        print("filling", len(empty), "unweighted verts by nearest bone")
        fallback_weights(body, rig, only=empty)
        empty = [v.index for v in body.data.vertices if not v.groups]
    if empty:
        body.vertex_groups["chest"].add(empty, 1.0, "REPLACE")
    body.data.validate()
    print("SOLDIER tris:", sum(len(p.vertices) - 2 for p in body.data.polygons), "verts:", len(body.data.vertices))
    print("JOINTS", {k: tuple(round(c, 3) for c in J[k]) for k in ("pelvis", "neck", "head", "l-shoulder", "l-elbow", "l-hand", "l-upper-leg", "l-knee", "l-ankle")})
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SRC, "soldier.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "soldier.glb"), export_format="GLB", use_selection=True,
                              export_yup=True, export_skins=True, export_animations=False, export_apply=False,
                              export_materials="EXPORT", export_texcoords=False, export_normals=True)
    print("EXPORTED", os.path.getsize(os.path.join(OUT, "soldier.glb")))


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



def build_boots(P_leg_r):
    """Our own sturdy boots (cuff + rounded foot), voxel-unioned and smoothed."""
    PARTS.clear()
    for sd in ("l", "r"):
        an = J[sd + "-ankle"]
        r = P_leg_r[sd] + 0.01
        _loft((an.x, BOOT_TOP - 0.004, an.z - 0.004), (an.x, 0.055, an.z), [(0, r, r * 1.03, 0), (1, r + 0.004, r * 1.06, 0)])
        toe_z = J[sd + "-foot-2"].z + 0.016
        _loft((an.x, 0.05, an.z - 0.068), (an.x + (0.008 if sd == "l" else -0.008), 0.046, toe_z),
              [(0, 0.056, 0.05, 0), (0.55, 0.062, 0.051, 0), (1, 0.053, 0.042, 0)], side_hint=(1, 0, 0))
    bm = bmesh.new()
    for part in PARTS:
        tmp = bpy.data.meshes.new("tmp")
        part.to_mesh(tmp)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    me = bpy.data.meshes.new("Boots")
    bm.to_mesh(me)
    ob = bpy.data.objects.new("Boots", me)
    bpy.context.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    m = ob.modifiers.new("Remesh", "REMESH")
    m.mode = "VOXEL"
    m.voxel_size = 0.006
    bpy.ops.object.modifier_apply(modifier="Remesh")
    sm = ob.modifiers.new("Smooth", "SMOOTH")
    sm.factor = 0.5
    sm.iterations = 6
    bpy.ops.object.modifier_apply(modifier="Smooth")
    for v in ob.data.vertices:
        if v.co.z < 0.015:
            v.co.z = max(v.co.z, 0.0) * 0.3
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    d = ob.modifiers.new("Dec", "DECIMATE")
    d.ratio = min(1.0, 800 / max(tris, 1))
    bpy.ops.object.modifier_apply(modifier="Dec")
    for p in ob.data.polygons:
        p.use_smooth = True
    _tag(ob, "is_boots")
    return ob



def _parts_to_object(name, voxel=0.006, smooth_iter=6, decimate=800, flatten_soles=False):
    bm = bmesh.new()
    for part in PARTS:
        tmp = bpy.data.meshes.new("tmp")
        part.to_mesh(tmp)
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    PARTS.clear()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    if voxel:
        m = ob.modifiers.new("Remesh", "REMESH")
        m.mode = "VOXEL"
        m.voxel_size = voxel
        bpy.ops.object.modifier_apply(modifier="Remesh")
    if smooth_iter:
        sm = ob.modifiers.new("Smooth", "SMOOTH")
        sm.factor = 0.5
        sm.iterations = smooth_iter
        bpy.ops.object.modifier_apply(modifier="Smooth")
    if flatten_soles:
        for v in ob.data.vertices:
            if v.co.z < 0.015:
                v.co.z = max(v.co.z, 0.0) * 0.3
    tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    if decimate and tris > decimate:
        d = ob.modifiers.new("Dec", "DECIMATE")
        d.ratio = min(1.0, decimate / max(tris, 1))
        bpy.ops.object.modifier_apply(modifier="Dec")
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def build_gloves():
    """Clean original tactical gloves: palm, four curled fingers, a tucked thumb. No spikes."""
    PARTS.clear()
    for sd, sg in (("l", 1), ("r", -1)):
        wr = WR[sd]
        d = (wr - EL[sd]).normalized()          # along the forearm, out to the fingers
        # Palm side axis: toward the body (inward) is a stable 'thumb side' for A-pose.
        inward = Vector((-sg, 0, 0))
        inward = (inward - d * inward.dot(d)).normalized()
        # Palm normal: roughly down / slightly forward so a grip curl closes the hand.
        n = d.cross(inward).normalized()
        if n.y > 0:
            n = -n
        lat = n.cross(d).normalized()           # across the palm, thumb is +lat * sg? thumb is inward
        thumb_side = inward
        # Palm
        palm0 = wr + d * 0.01
        palm1 = wr + d * 0.075
        _loft(tuple(palm0), tuple(palm1), [(0, 0.038, 0.026, 0), (1, 0.042, 0.028, 0)], seg=14, rings=8, side_hint=tuple(thumb_side))
        # Four fingers, slightly curled into a grip (along -n).
        spreads = [-0.028, -0.01, 0.008, 0.026]
        lengths = [0.055, 0.062, 0.058, 0.048]
        for sp, ln in zip(spreads, lengths):
            base = palm1 + thumb_side * sp + n * 0.004
            mid = base + d * (ln * 0.5) - n * 0.016
            tip = mid + d * (ln * 0.28) - n * 0.028
            _capsule(tuple(base), tuple(mid), 0.011, 0.01)
            _capsule(tuple(mid), tuple(tip), 0.01, 0.008)
        # Thumb: short, opposed across the palm, tucked — never a downward spike.
        t0 = palm0 + thumb_side * 0.03 + n * 0.006 + d * 0.012
        t1 = t0 + thumb_side * 0.01 + d * 0.028 - n * 0.008
        t2 = t1 + d * 0.018 - n * 0.01 + thumb_side * 0.004
        _capsule(tuple(t0), tuple(t1), 0.012, 0.011)
        _capsule(tuple(t1), tuple(t2), 0.011, 0.009)
    ob = _parts_to_object("Gloves", voxel=0.005, smooth_iter=5, decimate=900)
    _tag(ob, "is_gloves")
    return ob


def _tag(ob, name):
    g = ob.vertex_groups.new(name=name)
    g.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
    return ob


def _add_torus(center, major, minor, axis=(0, 1, 0), scale_xz=(1.0, 1.0), major_seg=20, minor_seg=8):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=major, minor_radius=minor,
        major_segments=major_seg, minor_segments=minor_seg,
        location=gv(center))
    ob = bpy.context.active_object
    z = (gv(Vector(center) + Vector(axis)) - gv(center)).normalized()
    ob.rotation_euler = Vector((0, 0, 1)).rotation_difference(z).to_euler()
    # Flatten in the torus plane: after a Z-aligned torus, X and Y are the ring; we want Godot X/Z.
    # Apply rotation first so we can scale in object space along residual axes when axis is Y (default).
    if axis[0] == 0 and axis[1] == 1 and axis[2] == 0:
        ob.scale = (scale_xz[0], scale_xz[1], 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return ob


def _ring_fit(body, y, ytol=0.02, pred=None):
    """Outside extents of the body at a given height (Godot space).

    Returns (x_half, z_forward, z_back) so a belt can be centred on a
    belly-heavier torso instead of floating off the back.
    """
    xs, zf, zb = [], [], []
    for v in body.data.vertices:
        g = bg(v.co)
        if abs(g.y - y) > ytol:
            continue
        if pred and not pred(g):
            continue
        xs.append(abs(g.x))
        (zf if g.z >= 0.0 else zb).append(abs(g.z))
    def pct(a, p):
        if not a:
            return 0.0
        a = sorted(a)
        return a[min(len(a) - 1, int(round((len(a) - 1) * p)))]
    return pct(xs, 0.9), pct(zf, 0.9), pct(zb, 0.9)


def build_kit(body):
    """Belt, crew-neck collar, rolled sleeve cuffs, and a couple of pocket shapes — so the uniform is not a onesie."""
    obs = []
    # Belt: fit a tight torus to the waist (slightly proud), plus a simple buckle.
    pred_w = lambda g: abs(g.x) < 0.28 and not _on_arm(g) and not _past_wrist(g)
    bx, bz_f, bz_b = _ring_fit(body, WAIST_Y, 0.02, pred_w)
    bmin = 0.016
    proud = bmin * 0.12
    bz = 0.5 * (bz_f + bz_b) + proud
    bcz = 0.5 * (bz_f - bz_b)  # shift forward if the belly is bigger than the back
    bmaj = max(0.12, (bx + proud + bz) * 0.5)
    bsz = ((bx + proud) / bmaj, bz / bmaj)
    print("BELT FIT", "x,zf,zb", (round(bx, 3), round(bz_f, 3), round(bz_b, 3)),
          "cz", round(bcz, 3), "maj", round(bmaj, 3), "scale", tuple(round(s, 3) for s in bsz))
    belt = _add_torus((0, WAIST_Y, bcz), bmaj, bmin, scale_xz=bsz)
    _tag(belt, "is_belt")
    obs.append(belt)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=gv((0, WAIST_Y, bcz + bz + 0.004)))
    buckle = bpy.context.active_object
    buckle.scale = (0.03, 0.012, 0.022)
    bpy.ops.object.transform_apply(scale=True)
    _tag(buckle, "is_belt")
    obs.append(buckle)
    # Crew-neck collar: fit a tight ring to the neck, slightly lower in front.
    cx, cz_f, cz_b = _ring_fit(body, COLLAR_Y + 0.006, 0.015, lambda g: abs(g.x) < 0.16 and not _on_arm(g))
    cmin = 0.011
    cproud = cmin * 0.2
    cz = 0.5 * (cz_f + cz_b) + cproud
    ccz = 0.5 * (cz_f - cz_b)
    cmaj = max(0.06, (cx + cproud + cz) * 0.5)
    csz = ((cx + cproud) / cmaj, cz / cmaj)
    print("COLLAR FIT", "x,zf,zb", (round(cx, 3), round(cz_f, 3), round(cz_b, 3)),
          "cz", round(ccz, 3), "maj", round(cmaj, 3), "scale", tuple(round(s, 3) for s in csz))
    col = _add_torus((0, COLLAR_Y + 0.006, ccz), cmaj, cmin, scale_xz=csz)
    for v in col.data.vertices:
        g = bg(v.co)
        if g.z > 0.02:
            v.co.z -= 0.016 * min(1.0, (g.z - 0.02) / 0.06)  # blender z = godot y, dip the front
    _tag(col, "is_collar")
    obs.append(col)
    # Rolled sleeve cuffs just above each wrist.
    for sd in ("l", "r"):
        d = (WR[sd] - EL[sd]).normalized()
        roll = _add_torus(tuple(WR[sd] - d * 0.055), 0.05, 0.014, axis=tuple(d))
        cuff = _add_torus(tuple(WR[sd] - d * 0.025), 0.048, 0.01, axis=tuple(d))
        _tag(roll, "is_cuffs")
        _tag(cuff, "is_cuffs")
        obs.extend([roll, cuff])
    # Chest and thigh pockets: thin rounded boxes, slightly proud.
    for s_ in (1, -1):
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=gv((0.07 * s_, J["spine-1"].y - 0.02, 0.145)))
        pock = bpy.context.active_object
        pock.scale = (0.032, 0.008, 0.038)
        bpy.ops.object.transform_apply(scale=True)
        bev = pock.modifiers.new("b", "BEVEL")
        bev.width = 0.004
        bev.segments = 2
        bpy.ops.object.modifier_apply(modifier="b")
        obs.append(pock)
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=gv((0.1 * s_, 0.62, 0.11)))
        tp = bpy.context.active_object
        tp.scale = (0.032, 0.01, 0.04)
        bpy.ops.object.transform_apply(scale=True)
        bev = tp.modifiers.new("b", "BEVEL")
        bev.width = 0.004
        bev.segments = 2
        bpy.ops.object.modifier_apply(modifier="b")
        obs.append(tp)
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    kit = bpy.context.active_object
    kit.name = "Kit"
    for p in kit.data.polygons:
        p.use_smooth = True
    return kit


def _hair_cut(g):
    hf, hb, zf, zb = HAIR
    t = min(max((g.z - zb) / (zf - zb), 0.0), 1.0)
    return hb + (hf - hb) * t


def _past_wrist(g):
    for sd in ("l", "r"):
        d = (WR[sd] - EL[sd]).normalized()
        if (g - (WR[sd] - d * 0.01)).dot(d) > 0 and (g - WR[sd]).length < 0.25:
            return True
    return False


def neckline_y(g):
    """Crew neck: dips in front, stays higher at the sides and back."""
    fwd = g.z - J["neck"].z
    return COLLAR_Y - 0.04 * max(0.0, fwd / 0.12) + 0.008 * max(0.0, -fwd / 0.12)


def region(g):
    # Belt/collar/cuffs are assigned only from is_* groups on the kit meshes.
    # Painting them onto body faces by radius made a jagged shirt/pants bite.
    if g.y < BOOT_TOP:
        return "boots"
    if _past_wrist(g):
        return "gloves"
    # Skin/shirt follows the collar cut plane so the neckline stays a clean loop.
    if g.y > COLLAR_Y and (g.y > J["head"].y or abs(g.x) < 0.085 or math.hypot(g.x, g.z - J["neck"].z) < 0.13):
        if g.y > _hair_cut(g) and not (abs(g.x) > 0.06 and g.y < EYE_Y + 0.025 and abs(g.z - J["head"].z) < 0.05):
            return "hair"
        return "skin"
    if g.y < WAIST_Y and abs(g.x) < 0.35:
        return "pants"
    return "top"


def _on_arm(g):
    for sd in ("l", "r"):
        if (g - EL[sd]).length < 0.12 or (g - WR[sd]).length < 0.16:
            return True
    return False


def _on_cuff(g):
    for sd in ("l", "r"):
        d = (WR[sd] - EL[sd]).normalized()
        t = (g - (WR[sd] - d * 0.055)).dot(d)
        rad = (g - (WR[sd] - d * 0.055) - d * t).length
        if -0.03 < t < 0.04 and 0.04 < rad < 0.09:
            return True
    return False


def _seam_geom(bm, pred):
    verts = [v for v in bm.verts if pred(bg(v.co))]
    vset = set(verts)
    edges = [e for e in bm.edges if e.verts[0] in vset or e.verts[1] in vset]
    faces = [f for f in bm.faces if any(v in vset for v in f.verts)]
    return verts + edges + faces


def clean_seams(body):
    """Cut clean material loops on the body only. Do not bisect the whole
    figure — a waist plane also slices the gloves (hands sit near WAIST_Y
    in bind pose) and inflates the tri count."""
    bm = bmesh.new()
    bm.from_mesh(body.data)
    cuts = [
        (gv((0, WAIST_Y, 0)), Vector((0, 0, 1)),
         lambda g: abs(g.y - WAIST_Y) < 0.06 and abs(g.x) < 0.28 and not _on_arm(g) and not _past_wrist(g)),
        (gv((0, BOOT_TOP, 0)), Vector((0, 0, 1)),
         lambda g: abs(g.y - BOOT_TOP) < 0.05 and abs(g.x) > 0.04 and g.y < 0.4),
        (gv((0, COLLAR_Y, 0)), Vector((0, 0, 1)),
         lambda g: abs(g.y - COLLAR_Y) < 0.05 and abs(g.x) < 0.16 and not _on_arm(g)),
    ]
    for sd in ("l", "r"):
        d = (WR[sd] - EL[sd]).normalized()
        side = 1 if sd == "l" else -1
        cuts.append((gv(WR[sd] - d * 0.01), gv(d) - gv((0, 0, 0)),
                     lambda g, d=d, wr=WR[sd], side=side: (g.x * side > 0.1) and (g - wr).length < 0.22))
        cuts.append((gv(WR[sd] - d * 0.07), gv(d) - gv((0, 0, 0)),
                     lambda g, d=d, wr=WR[sd], side=side: (g.x * side > 0.1) and (g - wr).length < 0.22))
    hf, hb, zf, zb = HAIR
    n = Vector((0, 1.0, -(hf - hb) / (zf - zb))).normalized()
    cuts.append((gv((0, hb, zb)), gv(n) - gv((0, 0, 0)),
                 lambda g: g.y > J["neck"].y - 0.02 and abs(g.x) < 0.16))
    for co, no, pred in cuts:
        geom = _seam_geom(bm, pred)
        if geom:
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no.normalized())
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(body.data)
    bm.free()


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
    c = lambda k: Vector((0.0, J[k].y, J[k].z))
    top = Vector((0.0, J["head-2"].y + 0.03, J["head"].z))
    bone("hips", c("pelvis"), c("spine-3"), roll_up=fwd)
    bone("spine", c("spine-3"), c("spine-2"), "hips", True, fwd)
    bone("spine1", c("spine-2"), c("spine-1"), "spine", True, fwd)
    bone("chest", c("spine-1"), c("neck"), "spine1", True, fwd)
    bone("neck", c("neck"), c("head"), "chest", True, fwd)
    bone("head", c("head"), top, "neck", True, fwd)
    for side, sd in (("L", "l"), ("R", "r")):
        bone("clavicle." + side, J[sd + "-clavicle"], J[sd + "-shoulder"], "chest", False, (0, 1, 0))
        bone("upper_arm." + side, J[sd + "-shoulder"], J[sd + "-elbow"], "clavicle." + side, True, fwd)
        bone("forearm." + side, J[sd + "-elbow"], J[sd + "-hand"], "upper_arm." + side, True, fwd)
        hd = J[sd + "-hand"] + (J[sd + "-finger-3-1"] - J[sd + "-hand"]).normalized() * 0.17
        bone("hand." + side, J[sd + "-hand"], hd, "forearm." + side, True, fwd)
        bone("thigh." + side, J[sd + "-upper-leg"], J[sd + "-knee"], "hips", False, fwd)
        bone("shin." + side, J[sd + "-knee"], J[sd + "-ankle"], "thigh." + side, True, fwd)
        bone("foot." + side, J[sd + "-ankle"], J[sd + "-foot-1"], "shin." + side, True, (0, 1, 0))
        bone("toe." + side, J[sd + "-foot-1"], J[sd + "-foot-2"] + (J[sd + "-foot-2"] - J[sd + "-foot-1"]) * 0.6, "foot." + side, True, (0, 1, 0))
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def smooth_weights(body):
    """Even out weights around neck / traps / shoulders / armpits so the girdle never pinches or doubles."""
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.mode_set(mode="EDIT")
    bm = bmesh.from_edit_mesh(body.data)
    lo = J["l-elbow"].y - 0.05
    for v in bm.verts:
        g = bg(v.co)
        v.select = lo < g.y < J["head"].y
    bm.select_flush(True)
    bmesh.update_edit_mesh(body.data)
    bpy.ops.object.mode_set(mode="WEIGHT_PAINT")
    body.data.use_paint_mask_vertex = True
    for _ in range(3):
        bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.5, repeat=3, expand=0.0)
    bpy.ops.object.mode_set(mode="OBJECT")
    body.data.use_paint_mask_vertex = False
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)


def mat(name, col, rough, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*col, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (*col, 1.0)
    return m



def fallback_weights(body, rig, only=None):
    """Nearest-bone weights if heat weighting fails (still blended to 2 nearest)."""
    only = set(only) if only is not None else None
    segs = []
    names = [g.name for g in body.vertex_groups]
    for b in rig.data.bones:
        segs.append((b.name, b.head_local.copy(), b.tail_local.copy()))
        if b.name not in names:
            body.vertex_groups.new(name=b.name)
    for v in body.data.vertices:
        if only is not None and v.index not in only:
            continue
        dists = []
        for name, a, t in segs:
            ab = t - a
            ln = ab.length_squared or 1e-8
            u = max(0.0, min(1.0, (v.co - a).dot(ab) / ln))
            dists.append(( (v.co - (a + ab * u)).length, name ))
        dists.sort()
        d0, d1 = dists[0][0], dists[1][0]
        w0 = 1.0 / max(d0, 0.01)
        w1 = 1.0 / max(d1, 0.01)
        s = w0 + w1
        # clear and assign
        for g in list(v.groups):
            body.vertex_groups[g.group].remove([v.index])
        body.vertex_groups[dists[0][1]].add([v.index], w0 / s, "REPLACE")
        body.vertex_groups[dists[1][1]].add([v.index], w1 / s, "REPLACE")




def add_clean_eyes(body):
    """Two simple dark irises, slightly proud of the lids. Tagged is_eyes, weighted later to head."""
    obs = []
    for sd in ("l", "r"):
        c = J[sd + "-eye"] + Vector((0, 0, 0.011))
        bpy.ops.mesh.primitive_uv_sphere_add(segments=14, ring_count=10, radius=0.014, location=gv(tuple(c)))
        e = bpy.context.active_object
        e.scale = (0.9, 0.5, 0.72)
        bpy.ops.object.transform_apply(scale=True)
        for p in e.data.polygons:
            p.use_smooth = True
        _tag(e, "is_eyes")
        obs.append(e)
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()


def assign_materials(body, eyeset):
    M = {
        "top": mat("uniform_top", (0.26, 0.29, 0.27), 0.88),
        "pants": mat("uniform_pants", (0.11, 0.125, 0.11), 0.9),
        "belt": mat("belt", (0.07, 0.06, 0.05), 0.55),
        "collar": mat("collar", (0.2, 0.22, 0.2), 0.86),
        "cuffs": mat("cuffs", (0.2, 0.22, 0.2), 0.86),
        "gloves": mat("gloves", (0.08, 0.08, 0.08), 0.65),
        "boots": mat("boots", (0.06, 0.06, 0.06), 0.55),
        "skin": mat("skin", (0.62, 0.47, 0.37), 0.8),
        "hair": mat("hair", (0.2, 0.12, 0.07), 0.95),
        "eyes": mat("eyes", (0.05, 0.04, 0.035), 0.3),
        "sclera": mat("sclera", (0.8, 0.78, 0.74), 0.4),
    }
    order = list(M.keys())
    for k in order:
        body.data.materials.append(M[k])
    me = body.data
    vg = {g.index: g.name for g in body.vertex_groups}
    for p in me.polygons:
        g = bg(p.center)
        names = set()
        for vi in p.vertices:
            for ge in me.vertices[vi].groups:
                if ge.weight > 0.4:
                    names.add(vg.get(ge.group, ""))
        if "is_eyes" in names:
            k = "eyes"
        elif "is_boots" in names:
            k = "boots"
        elif "is_gloves" in names:
            k = "gloves"
        elif "is_belt" in names:
            k = "belt"
        elif "is_collar" in names:
            k = "collar"
        elif "is_cuffs" in names:
            k = "cuffs"
        else:
            k = region(g)
            if k == "sclera":
                k = "skin"
        p.material_index = order.index(k)
    counts = {}
    for p in me.polygons:
        n = order[p.material_index]
        counts[n] = counts.get(n, 0) + 1
    print("MAT FACES", counts)


main()
