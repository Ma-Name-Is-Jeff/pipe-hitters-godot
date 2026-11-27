"""Pipe Hitters arena props (v1m): original low-poly props, all made here (no third-party assets).

Run:  /opt/blender/blender -b -P art/src/build_props.py
Out:  art/src/props.blend and art/models/props.glb  (one node per prop, base at y=0, centred on x/z)

Geometry is written in GODOT space (x right, y up, z forward, metres); G() converts to Blender.
Colours are per-face (COLOR_0, same numbers the level boxes use) so every prop shares ONE material
and the arena can draw each prop type as a single MultiMesh.
"""
import bpy, bmesh, math, os
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "art", "models")


def C(r, g, b):
    return (r / 255.0, g / 255.0, b / 255.0, 1.0)


def lit(c, k):
    return (min(c[0] * k, 1.0), min(c[1] * k, 1.0), min(c[2] * k, 1.0), 1.0)


# One cohesive muted night palette (matches the level's crate / cover tones).
WOOD_A, WOOD_B = C(98, 72, 44), C(80, 58, 36)
PLANK = C(128, 96, 58)
PINE, PINE_D = C(138, 106, 66), C(98, 74, 46)
DARK = C(46, 40, 34)
TIRE, TIRE_TOP, TIRE_IN = C(38, 39, 43), C(64, 65, 70), C(22, 22, 24)
BAR_A, BAR_A_D, BAR_A_LID = C(50, 74, 84), C(34, 50, 58), C(82, 106, 116)
BAR_B, BAR_B_D, BAR_B_LID = C(96, 44, 30), C(62, 34, 26), C(128, 76, 52)
CAR, CAR_TOP = C(88, 38, 32), C(116, 56, 44)
GLASS, TRIM = C(34, 46, 58), C(40, 42, 46)
HEAD, TAIL = C(214, 204, 160), C(168, 44, 38)
HUB = C(120, 122, 126)


class MB:
    def __init__(self):
        self.v, self.f, self.c, self.g = [], [], [], []
        self.gid = 0

    def face(self, pts, col):
        i = len(self.v)
        self.v.extend(pts)
        self.f.append(tuple(range(i, i + len(pts))))
        self.c.append(col)
        self.g.append(self.gid)

    def box(self, cx, cy, cz, sx, sy, sz, col, top=None, rot_y=0.0, rot_z=0.0, rot_x=0.0):
        """Axis box with its base at cy-sy/2; optional yaw / roll about its own centre."""
        self.gid += 1
        hx, hy, hz = sx / 2, sy / 2, sz / 2
        P = [Vector((x, y, z)) for x in (-hx, hx) for y in (-hy, hy) for z in (-hz, hz)]
        def T(p):
            x, y, z = p
            if rot_x:
                y, z = y * math.cos(rot_x) - z * math.sin(rot_x), y * math.sin(rot_x) + z * math.cos(rot_x)
            if rot_z:
                x, y = x * math.cos(rot_z) - y * math.sin(rot_z), x * math.sin(rot_z) + y * math.cos(rot_z)
            if rot_y:
                x, z = x * math.cos(rot_y) + z * math.sin(rot_y), -x * math.sin(rot_y) + z * math.cos(rot_y)
            return Vector((x + cx, y + cy, z + cz))
        q = lambda a, b, c, d: [T(P[a]), T(P[b]), T(P[c]), T(P[d])]
        # indices: x*4 + y*2 + z
        tc = top or lit(col, 1.12)
        self.face(q(4, 5, 7, 6), col)   # +x
        self.face(q(0, 2, 3, 1), col)   # -x
        self.face(q(2, 6, 7, 3), tc)    # +y
        self.face(q(0, 1, 5, 4), lit(col, 0.7))  # -y
        self.face(q(1, 3, 7, 5), col)   # +z
        self.face(q(0, 4, 6, 2), col)   # -z

    def lathe(self, prof, segs, ox=0.0, oy=0.0, oz=0.0, axis="y", closed=False):
        """prof: [(r, h, colour)] around the vertical axis (y); axis='z' lays it on its side."""
        self.gid += 1
        def pt(r, h, k):
            a = 2 * math.pi * k / segs
            x, z = r * math.cos(a), r * math.sin(a)
            if axis == "z":
                return Vector((ox + x, oy + z, oz + h))
            return Vector((ox + x, oy + h, oz + z))
        n = len(prof)
        for i in range(n if closed else n - 1):
            r0, h0, _ = prof[i]
            r1, h1, c1 = prof[(i + 1) % n]
            for k in range(segs):
                a, b = pt(r0, h0, k), pt(r0, h0, k + 1)
                c, d = pt(r1, h1, k + 1), pt(r1, h1, k)
                if r0 < 1e-6 and r1 < 1e-6:
                    continue
                if r0 < 1e-6:
                    self.face([a, c, d], c1)
                elif r1 < 1e-6:
                    self.face([a, b, c], c1)
                else:
                    self.face([a, b, c, d], c1)

    def frustum(self, y0, y1, bx0, bx1, bw, tx0, tx1, tw, cols):
        """cols: dict front/back/side/roof/floor. x along the car; front is +x."""
        self.gid += 1
        B = [(bx0, y0, -bw / 2), (bx1, y0, -bw / 2), (bx1, y0, bw / 2), (bx0, y0, bw / 2)]
        T = [(tx0, y1, -tw / 2), (tx1, y1, -tw / 2), (tx1, y1, tw / 2), (tx0, y1, tw / 2)]
        V = lambda p: Vector(p)
        self.face([V(B[1]), V(T[1]), V(T[2]), V(B[2])], cols["front"])
        self.face([V(B[3]), V(T[3]), V(T[0]), V(B[0])], cols["back"])
        self.face([V(B[0]), V(T[0]), V(T[1]), V(B[1])], cols["side"])
        self.face([V(B[2]), V(T[2]), V(T[3]), V(B[3])], cols["side"])
        self.face([V(T[0]), V(T[3]), V(T[2]), V(T[1])], cols["roof"])
        self.face([V(B[0]), V(B[1]), V(B[2]), V(B[3])], cols["floor"])

    def extrude_poly(self, poly, half_w, cols):
        """poly: [(x, y)] around the side profile (any winding); extruded along z."""
        self.gid += 1
        n = len(poly)
        L = [Vector((x, y, -half_w)) for x, y in poly]
        R = [Vector((x, y, half_w)) for x, y in poly]
        self.face(L[::-1], cols["side"])
        self.face(R, cols["side"])
        for i in range(n):
            j = (i + 1) % n
            (x0, y0), (x1, y1) = poly[i], poly[j]
            nrm_up = (x1 - x0) * 0 + (y1 - y0)
            col = cols["edge"](x0, y0, x1, y1)
            self.face([L[i], L[j], R[j], R[i]], col)


def G(v):
    return (v.x, -v.z, v.y)


def oriented_faces(mb):
    """Faces are emitted with unshared verts, so fix winding per primitive: weld its verts by position,
    let Blender make the normals point outward, then read the vertex order back."""
    out = [None] * len(mb.f)
    by_g = {}
    for fi, g in enumerate(mb.g):
        by_g.setdefault(g, []).append(fi)
    for g, fis in by_g.items():
        bm = bmesh.new()
        key = {}
        bf = []
        for fi in fis:
            idx = []
            for vi in mb.f[fi]:
                co = mb.v[vi]
                k = (round(co.x, 5), round(co.y, 5), round(co.z, 5))
                if k not in key:
                    key[k] = bm.verts.new(G(co))
                idx.append(key[k])
            bf.append(bm.faces.new(idx))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        inv = {v: k for k, v in key.items()}
        for fi, f in zip(fis, bf):
            out[fi] = [Vector(inv[v]) for v in f.verts]
        bm.free()
    return out


def to_object(name, mb):
    me = bpy.data.meshes.new(name + "Mesh")
    faces = oriented_faces(mb)
    verts, fidx, key = [], [], {}
    for pts in faces:
        idx = []
        for co in pts:
            k = (round(co.x, 6), round(co.y, 6), round(co.z, 6), len(fidx))
            verts.append(G(co))
            idx.append(len(verts) - 1)
        fidx.append(tuple(idx))
    me.from_pydata(verts, [], fidx)
    me.update()
    ca = me.color_attributes.new("Col", "FLOAT_COLOR", "CORNER")
    li = 0
    for poly, col in zip(me.polygons, mb.c):
        for _ in poly.loop_indices:
            ca.data[li].color = col
            li += 1
    me.color_attributes.active_color = ca
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


# ---------------------------------------------------------------- props
def crate():
    m = MB()
    m.box(0, 0.5, 0, 0.94, 0.94, 0.94, WOOD_B, top=lit(WOOD_A, 1.15))          # core
    for sx in (-1, 1):
        for sz in (-1, 1):
            m.box(sx * 0.44, 0.5, sz * 0.44, 0.12, 1.0, 0.12, PLANK)            # corner posts
    for y in (0.05, 0.95):                                                       # top and bottom rails
        for s in (-1, 1):
            m.box(0, y, s * 0.44, 0.80, 0.10, 0.12, PLANK, top=lit(PLANK, 1.1))
            m.box(s * 0.44, y, 0, 0.12, 0.10, 0.80, PLANK, top=lit(PLANK, 1.1))
    for s in (-1, 1):                                                            # diagonal braces on all four faces
        m.box(0, 0.5, s * 0.485, 0.98, 0.09, 0.03, WOOD_A, rot_z=math.atan2(0.76, 0.76))
        m.box(s * 0.485, 0.5, 0, 0.03, 0.09, 0.98, WOOD_A, rot_x=math.atan2(0.76, 0.76))
    # the top face is a lighter lid so it reads at night from above
    m.box(0, 0.965, 0, 0.78, 0.04, 0.78, lit(WOOD_A, 1.3), top=lit(PLANK, 1.05))
    return m


def box_small():
    """Wooden box 0.9 x 0.62 high x 0.64: slatted sides, lid with two cleats."""
    m = MB()
    m.box(0, 0.29, 0, 0.84, 0.58, 0.58, WOOD_B)
    for z in (-1, 1):
        for y in (0.12, 0.30, 0.48):
            m.box(0, y, z * 0.30, 0.9, 0.14, 0.04, WOOD_A if y != 0.30 else PLANK, top=lit(WOOD_A, 1.1))
    for x in (-1, 1):
        for y in (0.12, 0.30, 0.48):
            m.box(x * 0.43, y, 0, 0.04, 0.14, 0.62, WOOD_A if y != 0.30 else PLANK, top=lit(WOOD_A, 1.1))
    m.box(0, 0.585, 0, 0.88, 0.07, 0.62, lit(PLANK, 1.0), top=lit(PLANK, 1.18))
    for x in (-0.28, 0.28):
        m.box(x, 0.63, 0, 0.10, 0.03, 0.56, PINE_D, top=lit(PINE_D, 1.2))
    return m


def add_pallet(m, y0=0.0):
    """One pallet 1.2 (x) x 1.0 (z) x 0.144 high: 3 bottom boards, 3 stringers, 5 deck boards."""
    for z in (-0.41, 0.0, 0.41):
        m.box(0, y0 + 0.011, z, 1.2, 0.022, 0.16, PINE_D, top=lit(PINE_D, 1.1))
    for x in (-0.5, 0.0, 0.5):
        m.box(x, y0 + 0.07, 0, 0.12, 0.1, 0.96, PINE_D, top=lit(PINE_D, 1.05))
    for i, z in enumerate((-0.4, -0.2, 0.0, 0.2, 0.4)):
        m.box(0, y0 + 0.133, z, 1.2, 0.022, 0.15, PINE if i % 2 == 0 else lit(PINE, 0.93), top=lit(PINE, 1.2))


def pallet():
    m = MB()
    add_pallet(m)
    return m


def pallet_stack():
    m = MB()
    for i in range(5):
        add_pallet(m, i * 0.144)
    return m


def add_tire(m, y0, spin=0.0):
    R, r, w = 0.38, 0.2, 0.22
    prof = [(r, 0.0, TIRE_IN), (r + 0.02, 0.0, TIRE_TOP), (R - 0.03, 0.0, TIRE_TOP), (R, 0.04, TIRE),
            (R, w - 0.04, TIRE), (R - 0.03, w, TIRE_TOP), (r + 0.02, w, TIRE_TOP), (r, w, TIRE_IN)]
    # lathe on the vertical axis; closed loop through the bore
    m.lathe([(a, b + y0, c) for a, b, c in prof], 12, closed=True)


def tires(n):
    m = MB()
    for i in range(n):
        add_tire(m, i * 0.22)
    return m


def barrel(body, band, lid):
    m = MB()
    prof = [(0, 0.0, band), (0.24, 0.0, band), (0.285, 0.06, band), (0.298, 0.2, body),
            (0.312, 0.2, band), (0.312, 0.25, band), (0.30, 0.25, body), (0.31, 0.46, body),
            (0.30, 0.66, body), (0.312, 0.66, band), (0.312, 0.71, band), (0.298, 0.71, body),
            (0.285, 0.86, body), (0.262, 0.92, lid), (0.23, 0.92, lid), (0.23, 0.895, band), (0, 0.895, lit(lid, 1.05))]
    m.lathe(prof, 12)
    return m


def car():
    m = MB()
    half_w = 0.88
    poly = [(-2.12, 0.30), (2.12, 0.30), (2.17, 0.55), (2.10, 0.80), (1.42, 0.92), (-1.46, 0.92), (-2.12, 0.86), (-2.17, 0.55)]
    def edge(x0, y0, x1, y1):
        if y0 == y1 and y0 == 0.30:
            return TRIM
        if y0 == y1:
            return CAR_TOP
        if x0 == x1 or abs(x1 - x0) < 0.2:
            return CAR
        return CAR_TOP if (y1 > y0 and x1 < x0) or (y1 < y0 and x1 < x0) else CAR
    m.extrude_poly(poly, half_w, {"side": CAR, "edge": edge})
    # cabin: sloped windscreen, glass sides, light roof
    m.frustum(0.92, 1.45, -1.50, 1.28, 1.70, -0.92, 0.42, 1.42,
              {"front": GLASS, "back": GLASS, "side": GLASS, "roof": CAR_TOP, "floor": TRIM})
    # bumpers, lights, door seams, underside
    m.box(2.15, 0.46, 0, 0.12, 0.26, 1.72, TRIM)
    m.box(-2.15, 0.46, 0, 0.12, 0.26, 1.72, TRIM)
    for z in (-0.62, 0.62):
        m.box(2.16, 0.64, z, 0.05, 0.12, 0.30, HEAD, top=HEAD)
        m.box(-2.17, 0.64, z, 0.05, 0.12, 0.30, TAIL, top=TAIL)
    for z in (-1, 1):
        m.box(0.05, 0.60, z * 0.885, 0.025, 0.46, 0.02, TRIM)
        m.box(-0.95, 0.60, z * 0.885, 0.025, 0.46, 0.02, TRIM)
        m.box(0.95, 0.60, z * 0.885, 0.025, 0.46, 0.02, TRIM)
    m.box(0, 0.30, 0, 4.2, 0.06, 1.7, TRIM)
    # wheels (axis along z)
    for x in (-1.32, 1.32):
        for z in (-1, 1):
            prof = [(0, -0.10, HUB), (0.20, -0.10, HUB), (0.34, -0.08, TIRE), (0.34, 0.08, TIRE), (0.20, 0.10, TRIM), (0, 0.10, TRIM)]
            m.lathe(prof, 12, ox=x, oy=0.34, oz=z * 0.78, axis="z")
    return m


PROPS = {
    "crate": crate, "box": box_small, "pallet": pallet, "pallet_stack": pallet_stack,
    "tire_stack3": lambda: tires(3), "tire_stack4": lambda: tires(4), "tire_tower": lambda: tires(6),
    "barrel_a": lambda: barrel(BAR_A, BAR_A_D, BAR_A_LID), "barrel_b": lambda: barrel(BAR_B, BAR_B_D, BAR_B_LID),
    "car": car,
}


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    objs = []
    for name, fn in PROPS.items():
        ob = to_object(name, fn())
        objs.append(ob)
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        bb = [Vector(c) for c in ob.bound_box]
        sx = max(b.x for b in bb) - min(b.x for b in bb)
        sy = max(b.z for b in bb) - min(b.z for b in bb)
        sz = max(b.y for b in bb) - min(b.y for b in bb)
        print("PROP %-12s tris %4d  size(x,h,z) = %.3f %.3f %.3f  min_y %.3f" % (name, tris, sx, sy, sz, min(b.z for b in bb)))
    mat = bpy.data.materials.new("props")
    mat.use_nodes = True
    for ob in objs:
        ob.data.materials.append(mat)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "src", "props.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    kw = dict(filepath=os.path.join(OUT, "props.glb"), export_format="GLB", use_selection=True, export_yup=True,
              export_apply=True, export_texcoords=False, export_normals=True, export_materials="EXPORT")
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
    except TypeError:
        bpy.ops.export_scene.gltf(export_active_vertex_color_when_no_material=True, **kw)
    print("TOTAL tris", sum(len(p.vertices) - 2 for o in objs for p in o.data.polygons), "EXPORTED", os.path.getsize(os.path.join(OUT, "props.glb")))


main()
