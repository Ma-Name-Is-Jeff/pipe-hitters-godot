"""Pipe Hitters soldier (v1k): CC0 MakeHuman base mesh, customized into our own soldier.

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
TARGET_TRIS = 6300
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
    # 3) gloved hands: slightly larger, fingers curled into a grip
    for sd, sg in (("l", 1), ("r", -1)):
        wr = J[sd + "-hand"]
        d = (J[sd + "-finger-3-1"] - wr).normalized()
        lat = (J[sd + "-finger-2-1"] - J[sd + "-finger-5-1"]).normalized()
        n = d.cross(lat).normalized()
        if n.x * sg > 0:
            n = -n
        chains = {f: [J["%s-finger-%d-%d" % (sd, f, j)].copy() for j in range(1, 5)] for f in range(1, 6)}
        ang = {1: (0.35, 0.45, 0.35), 2: (0.9, 1.2, 0.7), 3: (0.95, 1.25, 0.7), 4: (1.0, 1.25, 0.7), 5: (1.05, 1.2, 0.7)}
        for i, g in enumerate(P):
            if is_eye[i] or (g - wr).length > 0.25 or (g - wr).dot(d) < 0.0:
                continue
            best, bf, bk, bt = 1e9, None, 0, 0.0
            for f, ch in chains.items():
                for k in range(3):
                    a_, b_ = ch[k], ch[k + 1]
                    ab = b_ - a_
                    t = max(-0.6, min(1.0, (g - a_).dot(ab) / ab.length_squared))
                    dist = (a_ + ab * max(t, 0.0) - g).length
                    if dist < best:
                        best, bf, bk, bt = dist, f, k, t
            g2 = wr + (g - wr) * HAND_SCALE
            if bf is not None and not (bk == 0 and bt < 0.0):
                ch = [wr + (c - wr) * HAND_SCALE for c in chains[bf]]
                fd = (ch[1] - ch[0]).normalized()
                ax = fd.cross(n).normalized()
                for k in range(bk + 1):
                    w = 1.0 if k < bk else min(1.0, max(0.0, bt * 4.0 if k == 0 else 1.0))
                    R = Matrix.Rotation(ang[bf][k] * w, 3, ax)
                    piv = ch[k]
                    g2 = piv + R @ (g2 - piv)
                    ch = [piv + R @ (c - piv) if j > k else c for j, c in enumerate(ch)]
            P[i] = g2
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
    # 5) boots: our own boot geometry replaces the bare feet (MH verts below the boot are removed)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if bg(v.co).y < 0.13 and v not in eye_verts], context="VERTS")
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
    boots = build_boots(LEG_R)
    bpy.ops.object.select_all(action="DESELECT")
    boots.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()
    clean_seams(body)
    for p in body.data.polygons:
        p.use_smooth = True
    rig = build_armature()
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    # eyeballs ride the head bone only
    eyeset = set(v.index for v in body.data.vertices if any(g.group == body.vertex_groups["eyeball"].index for g in v.groups))
    for g_ in body.vertex_groups:
        if g_.name not in ("head", "eyeball"):
            g_.remove(list(eyeset))
    body.vertex_groups["head"].add(list(eyeset), 1.0, "REPLACE")
    body.vertex_groups.remove(body.vertex_groups["eyeball"])
    smooth_weights(body)
    empty = [v.index for v in body.data.vertices if not v.groups]
    print("verts without weights:", len(empty))
    if empty:
        body.vertex_groups["chest"].add(empty, 1.0, "REPLACE")
    assign_materials(body, eyeset)
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
        r = P_leg_r[sd] + 0.02
        _loft((an.x, BOOT_TOP - 0.004, an.z - 0.005), (an.x, 0.07, an.z), [(0, r, r * 1.04, 0), (1, r + 0.006, r * 1.08, 0)])
        toe_z = J[sd + "-foot-2"].z + 0.04
        _loft((an.x, 0.062, an.z - 0.085), (an.x + (0.01 if sd == "l" else -0.01), 0.058, toe_z),
              [(0, 0.07, 0.062, 0), (0.55, 0.077, 0.064, 0), (1, 0.066, 0.052, 0)], side_hint=(1, 0, 0))
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
    d.ratio = min(1.0, 1100 / max(tris, 1))
    bpy.ops.object.modifier_apply(modifier="Dec")
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


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


def region(g):
    if g.y < BOOT_TOP:
        return "boots"
    if _past_wrist(g):
        return "gloves"
    if g.y > COLLAR_Y and (g.y > J["head"].y or abs(g.x) < 0.075 or math.hypot(g.x, g.z - J["neck"].z) < 0.1):
        if g.y > _hair_cut(g) and not (abs(g.x) > 0.06 and g.y < EYE_Y + 0.025 and abs(g.z - J["head"].z) < 0.05):
            return "hair"
        return "skin"
    if g.y < WAIST_Y and abs(g.x) < 0.3:
        return "pants"
    return "top"


def clean_seams(body):
    bm = bmesh.new()
    bm.from_mesh(body.data)
    cuts = [(gv((0, WAIST_Y, 0)), Vector((0, 0, 1))), (gv((0, BOOT_TOP, 0)), Vector((0, 0, 1))),
            (gv((0, COLLAR_Y, 0)), Vector((0, 0, 1)))]
    for sd in ("l", "r"):
        d = (WR[sd] - EL[sd]).normalized()
        cuts.append((gv(WR[sd] - d * 0.01), gv(d) - gv((0, 0, 0))))
    hf, hb, zf, zb = HAIR
    n = Vector((0, 1.0, -(hf - hb) / (zf - zb))).normalized()   # godot-space plane normal (y up, tilted)
    cuts.append((gv((0, hb, zb)), gv(n) - gv((0, 0, 0))))
    for co, no in cuts:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
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


def assign_materials(body, eyeset):
    M = {
        "top": mat("uniform_top", (0.2, 0.21, 0.19), 0.88),
        "pants": mat("uniform_pants", (0.16, 0.17, 0.15), 0.9),
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
    head_c = None
    for p in me.polygons:
        g = bg(p.center)
        if all(vi in eyeset for vi in p.vertices):
            n = bg(p.normal) if False else Vector((p.normal.x, p.normal.z, -p.normal.y))
            k = "eyes" if n.z > 0.86 else "sclera"
        else:
            k = region(g)
        p.material_index = order.index(k)


main()
