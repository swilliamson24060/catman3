import re
import shutil
import urllib.request
from pathlib import Path

try:
    import bpy
    import mathutils
except Exception:
    bpy = None
    mathutils = None

USER_AGENT = "Mozilla/5.0"
DEFAULT_STONE_FLOOR_SLUG = "granite_tile"

STONE_FLOOR_1K_URLS = [
    "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/granite_tile/granite_tile_diff_1k.jpg",
    "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/granite_tile/granite_tile_nor_gl_1k.jpg",
    "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/granite_tile/granite_tile_rough_1k.jpg",
    "https://dl.polyhaven.org/file/ph-assets/Textures/png/1k/granite_tile/granite_tile_disp_1k.png",
    "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/granite_tile/granite_tile_arm_1k.jpg",
    "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/1k/granite_tile/granite_tile_ao_1k.jpg",
]


def fetch_text(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", "replace")


def find_candidate_slug() -> str:
    return DEFAULT_STONE_FLOOR_SLUG


def discover_download_urls(slug: str):
    page_url = f"https://polyhaven.com/a/{slug}"
    try:
        html = fetch_text(page_url)
    except Exception:
        return list(STONE_FLOOR_1K_URLS)

    urls = sorted(set(re.findall(
        r'https?://dl\.polyhaven\.(?:org|com)/file/ph-assets/[^"\'\s>]+',
        html,
        re.IGNORECASE
    )))
    if urls:
        return urls

    return list(STONE_FLOOR_1K_URLS)


def download_map(url: str, dest_dir: Path) -> Path:
    filename = url.split("/")[-1]
    dest = dest_dir / filename
    if dest.exists():
        return dest

    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response, open(dest, "wb") as fh:
        shutil.copyfileobj(response, fh)
    return dest


def choose_file(urls, *keywords):
    for kw in keywords:
        lower_kw = kw.lower()
        for url in urls:
            if lower_kw in url.lower():
                return url
    return None


def ensure_blender():
    if bpy is None:
        raise RuntimeError("This script must be run from Blender's Scripting workspace.")


def get_socket(node, names, socket_type=None):
    for name in names:
        if name in node.inputs:
            socket = node.inputs[name]
            if socket_type is None or socket.type == socket_type:
                return socket
    return None


def safe_set_default(node, names, value):
    socket = get_socket(node, names)
    if socket is not None:
        socket.default_value = value


def assign_material_to_selected_object(material_name: str, color_path: str, roughness_path: str = None, normal_path: str = None):
    ensure_blender()

    obj = bpy.context.active_object
    if obj is None or obj.type not in {"MESH", "CURVE", "SURFACE"}:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.mesh.primitive_cube_add(size=2.0)
        obj = bpy.context.active_object
        if obj is None or obj.type not in {"MESH", "CURVE", "SURFACE"}:
            raise RuntimeError("Please select a mesh-like object before running this script.")

    if not color_path or not Path(color_path).exists():
        raise RuntimeError(f"Color texture file not found: {color_path}")

    mat = bpy.data.materials.new(name=material_name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links

    for node in list(nodes):
        nodes.remove(node)

    output = nodes.new(type="ShaderNodeOutputMaterial")
    output.location = (700, 0)

    bsdf = nodes.new(type="ShaderNodeBsdfPrincipled")
    bsdf.location = (400, 0)
    safe_set_default(bsdf, ("Roughness",), 0.8)
    safe_set_default(bsdf, ("Metallic",), 0.0)
    safe_set_default(bsdf, ("Specular IOR Level", "Specular"), 0.35)

    surface_socket = get_socket(output, ("Surface",))
    if surface_socket is not None:
        links.new(bsdf.outputs["BSDF"], surface_socket)

    texcoord = nodes.new(type="ShaderNodeTexCoord")
    texcoord.location = (-1200, 200)

    mapping = nodes.new(type="ShaderNodeMapping")
    mapping.location = (-980, 200)
    scale_socket = get_socket(mapping, ("Scale",))
    if scale_socket is not None:
        scale_socket.default_value = (2.0, 2.0, 2.0)
    uv_out = texcoord.outputs.get("UV")
    vector_in = get_socket(mapping, ("Vector",))
    if uv_out and vector_in:
        links.new(uv_out, vector_in)

    color_tex = nodes.new(type="ShaderNodeTexImage")
    color_tex.location = (-760, 220)
    color_tex.image = bpy.data.images.load(color_path)
    if hasattr(color_tex.image, "colorspace_settings"):
        color_tex.image.colorspace_settings.name = "sRGB"
    if vector_in:
        links.new(mapping.outputs["Vector"], color_tex.inputs["Vector"])

    color_ramp = nodes.new(type="ShaderNodeValToRGB")
    color_ramp.location = (-480, 220)
    if len(color_ramp.color_ramp.elements) >= 3:
        color_ramp.color_ramp.elements[0].position = 0.0
        color_ramp.color_ramp.elements[0].color = (0.18, 0.18, 0.18, 1.0)
        color_ramp.color_ramp.elements[1].position = 0.55
        color_ramp.color_ramp.elements[1].color = (0.62, 0.60, 0.56, 1.0)
        color_ramp.color_ramp.elements[2].position = 1.0
        color_ramp.color_ramp.elements[2].color = (0.84, 0.82, 0.79, 1.0)
    links.new(color_tex.outputs["Color"], color_ramp.inputs["Fac"])

    pastel = nodes.new(type="ShaderNodeRGB")
    pastel.location = (-480, 40)
    if pastel.outputs:
        pastel.outputs[0].default_value = (0.96, 0.81, 0.73, 1.0)

    mix_color = nodes.new(type="ShaderNodeMixRGB")
    mix_color.location = (-220, 140)
    mix_color.blend_type = 'MIX'
    fac_socket = get_socket(mix_color, ("Fac",))
    if fac_socket is not None:
        fac_socket.default_value = 0.45
    links.new(color_ramp.outputs["Color"], mix_color.inputs["Color1"])
    links.new(pastel.outputs["Color"], mix_color.inputs["Color2"])
    base_color_socket = get_socket(bsdf, ("Base Color",))
    if base_color_socket is not None:
        links.new(mix_color.outputs["Color"], base_color_socket)

    if roughness_path and Path(roughness_path).exists():
        rough_tex = nodes.new(type="ShaderNodeTexImage")
        rough_tex.location = (-760, -120)
        rough_tex.image = bpy.data.images.load(roughness_path)
        if hasattr(rough_tex.image, "colorspace_settings"):
            rough_tex.image.colorspace_settings.name = "Non-Color"
        links.new(mapping.outputs["Vector"], rough_tex.inputs["Vector"])

        rough_ramp = nodes.new(type="ShaderNodeValToRGB")
        rough_ramp.location = (-500, -120)
        if len(rough_ramp.color_ramp.elements) >= 3:
            rough_ramp.color_ramp.elements[0].position = 0.0
            rough_ramp.color_ramp.elements[0].color = (0.25, 0.25, 0.25, 1.0)
            rough_ramp.color_ramp.elements[1].position = 0.7
            rough_ramp.color_ramp.elements[1].color = (0.80, 0.80, 0.80, 1.0)
            rough_ramp.color_ramp.elements[2].position = 1.0
            rough_ramp.color_ramp.elements[2].color = (0.95, 0.95, 0.95, 1.0)
        links.new(rough_tex.outputs["Color"], rough_ramp.inputs["Fac"])
        roughness_socket = get_socket(bsdf, ("Roughness",))
        if roughness_socket is not None:
            links.new(rough_ramp.outputs["Color"], roughness_socket)

    if normal_path and Path(normal_path).exists():
        norm_tex = nodes.new(type="ShaderNodeTexImage")
        norm_tex.location = (-760, -360)
        norm_tex.image = bpy.data.images.load(normal_path)
        if hasattr(norm_tex.image, "colorspace_settings"):
            norm_tex.image.colorspace_settings.name = "Non-Color"
        links.new(mapping.outputs["Vector"], norm_tex.inputs["Vector"])

        normal_map = nodes.new(type="ShaderNodeNormalMap")
        normal_map.location = (-430, -360)
        strength_socket = get_socket(normal_map, ("Strength",))
        if strength_socket is not None:
            strength_socket.default_value = 0.15
        normal_socket = get_socket(bsdf, ("Normal",))
        if normal_socket is not None:
            links.new(norm_tex.outputs["Color"], normal_map.inputs["Color"])
            links.new(normal_map.outputs["Normal"], normal_socket)

    if obj.data and hasattr(obj.data, "materials"):
        obj.data.materials.clear()
        obj.data.materials.append(mat)


def setup_three_point_lighting():
    ensure_blender()

    obj = bpy.context.active_object
    if obj is None:
        return

    target = mathutils.Vector(obj.location)
    if hasattr(obj, "bound_box") and obj.bound_box:
        dims = obj.dimensions if hasattr(obj, "dimensions") else (1.0, 1.0, 1.0)
        target = target + mathutils.Vector((dims[0] * 0.5, dims[1] * 0.5, dims[2] * 0.5))

    def remove_existing_light(name):
        if name in bpy.data.objects:
            bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
        if name in bpy.data.lights:
            bpy.data.lights.remove(bpy.data.lights[name], do_unlink=True)

    for name in ("KeyLight", "FillLight", "RimLight"):
        remove_existing_light(name)

    def add_light(name, location, rotation, energy, color):
        light_data = bpy.data.lights.new(name=name, type='AREA')
        light_data.energy = energy
        light_data.color = color
        light_data.shape = 'RECTANGLE'
        light_data.size = 2.8
        light_data.size_y = 2.8
        light_data.use_shadow = True

        light_obj = bpy.data.objects.new(name=name, object_data=light_data)
        bpy.context.collection.objects.link(light_obj)
        light_obj.location = location
        light_obj.rotation_euler = rotation
        return light_obj

    key_loc = target + mathutils.Vector((4.5, -5.0, 4.5))
    fill_loc = target + mathutils.Vector((-4.0, 3.2, 3.6))
    rim_loc = target + mathutils.Vector((0.0, 5.5, 4.8))

    add_light("KeyLight", key_loc, (1.1, 0.0, 0.7), 2400.0, (1.0, 0.95, 0.88))
    add_light("FillLight", fill_loc, (1.0, 0.0, 2.25), 1100.0, (0.72, 0.82, 1.0))
    add_light("RimLight", rim_loc, (0.95, 0.0, 3.14), 1400.0, (0.85, 0.9, 1.0))

    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.88, 0.9, 0.95, 1.0)
        bg.inputs["Strength"].default_value = 0.35


def main():
    ensure_blender()

    slug = find_candidate_slug()
    urls = discover_download_urls(slug)

    if not urls:
        raise RuntimeError(f"No downloadable texture URLs were found for asset slug '{slug}'.")

    base_dir = Path(bpy.path.abspath("//polyhaven_stone_floor"))
    base_dir.mkdir(parents=True, exist_ok=True)

    diff_url = choose_file(urls, "diff", "albedo", "color")
    roughness_url = choose_file(urls, "roughness", "rough", "spec")
    normal_url = choose_file(urls, "normal", "bump")

    if not diff_url:
        raise RuntimeError(f"Could not find a color map in the Poly Haven download list for '{slug}'.")

    diff_file = download_map(diff_url, base_dir)
    roughness_file = download_map(roughness_url, base_dir) if roughness_url else None
    normal_file = download_map(normal_url, base_dir) if normal_url else None

    print(f"Selected Poly Haven slug: {slug}")
    print(f"Downloaded to: {base_dir}")
    assign_material_to_selected_object(
        material_name=f"PH_{slug}",
        color_path=str(diff_file),
        roughness_path=str(roughness_file) if roughness_file else None,
        normal_path=str(normal_file) if normal_file else None,
    )
    setup_three_point_lighting()
    print("Material applied and 3-point lighting added to the scene.")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print("Poly Haven stone floor setup failed:", exc)
        raise