#!/usr/bin/env python3
"""
Generates per-founder cat textures by palette-swapping the REAL colormap.png
the cat model actually uses, rather than replacing it with a flat color.

Why this exists: the "body" mesh's fur is painted into colormap.png at a
handful of swatch locations and sampled via UV on a single mesh surface. A
flat material override erases it entirely. This script instead recolors
only the fur pixel cluster the body mesh actually samples (found by
inspecting real UVs against the texture at runtime), leaving the rest of
the shared Kenney atlas untouched.

Eye anatomy on this mesh (found via triangle-level UV/geometry analysis,
see core/render_screenshot.gd history):
  - The visible "white" ring of each eye socket samples a dedicated
    golden-yellow gradient swatch (UV x=0.96875, y in [0.524990,
    0.605020], i.e. pixel column x=496, rows y=~268..310). We patch this
    to actual white.
  - The pupil is NOT a dedicated swatch. Every pupil vertex (both eyes)
    maps to UV x=0.96875 with y ranging from 0.774990 to 0.974990 -- i.e.
    pixel column x=496, rows y=397..499. That is the SAME vertical fur
    gradient ramp the small "Group" decorative mesh also samples. Because
    it's inside the fur ramp, recoloring fur also recolors the pupil (e.g.
    to a tabby stripe instead of solid black). To make the pupils glow
    with the founder's eye_color, we patch that whole pixel column LAST,
    after fur recoloring, so it wins.

Tabby stripe direction -- why this is NOT done in the texture:
This low-poly model's whole fur surface is UV-mapped to just THREE narrow
texture columns (x=0.094, 0.844, 0.969), and critically each column is
MIRRORED across the body's left/right halves -- e.g. column x=0.844 is
shared by faces spanning local X from -0.625 to +0.625 (confirmed via
body_mesh_dump2.json: average 3D X per column is ~0, i.e. left- and
right-side geometry paint the exact same pixels). That means there is NO
texture pixel that belongs to only the left side or only the right side --
recoloring texture space can only vary fur color with height (Y), which
renders as horizontal rings, never as bands that alternate left-to-right.
That's a hard limitation of this asset's UV unwrap, not a formula choice.

So instead, tabby-patterned founders get their body drawn via a small
custom shader (founder/tabby_stripes.gdshader) that reads the FRAGMENT's
true object-space position (which varies correctly and continuously across
a face regardless of how degenerate its UV is) and stripes between
body_color/secondary_color based on that. This script's job for a tabby
founder is just to paint the fur pixels a single flat body_color (the
shader repaints stripes on top of it at runtime) and to also emit a
fur-mask texture telling the shader which texels are fur vs. eye/other.

Run this again any time cats.json's coat colors change, or the mesh dump
is refreshed:
    python3 tools/generate_cat_textures.py

Outputs, per founder id:
    founder/textures/cat_<id>_albedo.png  (fur = flat body_color, eye
                                            whites patched white, pupils
                                            patched to eye_color)
    founder/textures/cat_<id>_furmask.png (grayscale: 255 = fur pixel,
                                            0 = everything else. Only
                                            emitted for tabby founders --
                                            solid-pattern founders don't
                                            need the stripe shader.)
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
COLORMAP_PATH = ROOT / "kenney_cube-pets_1" / "Models" / "Textures" / "colormap.png"
CATS_JSON_PATH = ROOT / "data" / "cats.json"
OUTPUT_DIR = ROOT / "founder" / "textures"

# Empirically sampled by walking the body mesh's real UVs against
# colormap.png (see core/uv_inspect.gd history).
FUR_REFS = np.array([
    (104, 105, 126), (108, 110, 131), (130, 135, 157), (127, 131, 153),
    (75, 78, 92), (61, 63, 75), (82, 85, 100), (61, 64, 76), (62, 64, 76),
    (65, 68, 81), (71, 74, 87), (76, 79, 94), (80, 84, 99), (101, 101, 122),
    (123, 126, 148), (111, 113, 134), (147, 153, 184), (125, 130, 156),
    (68, 70, 83), (77, 80, 94), (126, 130, 151), (118, 121, 142),
    (110, 111, 132), (109, 110, 131), (117, 119, 141), (124, 128, 150),
    (119, 122, 143), (147, 154, 185), (164, 172, 206),
], dtype=np.int16)

MATCH_TOLERANCE = 30

# Pixel column/row range every pupil vertex samples (UV x=0.96875 fixed,
# y in [0.774990, 0.974990]) * 512x512, patched with a small margin on x to
# stay correct under bilinear filtering.
PUPIL_PATCH_X = (490, 502)
PUPIL_PATCH_Y = (394, 502)

# Pixel column/row range every eye-white vertex samples (UV x=0.96875
# fixed, y in [0.524990, 0.605020]), patched with a small margin on x.
WHITE_PATCH_X = (490, 502)
WHITE_PATCH_Y = (262, 316)
WHITE_COLOR = np.array((255, 255, 255), dtype=np.uint8)


def hex_to_rgb(hex_str: str) -> tuple[int, int, int]:
    hex_str = hex_str.lstrip("#")
    return tuple(int(hex_str[i:i + 2], 16) for i in (0, 2, 4))


def min_dist(arr: np.ndarray, refs: np.ndarray) -> np.ndarray:
    diffs = arr[:, :, None, :].astype(np.int32) - refs[None, None, :, :].astype(np.int32)
    d2 = (diffs ** 2).sum(axis=-1)
    return np.sqrt(d2.min(axis=-1))


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    base_img = Image.open(COLORMAP_PATH).convert("RGB")
    arr = np.array(base_img)

    fur_dist = min_dist(arr, FUR_REFS)
    is_fur = fur_dist < MATCH_TOLERANCE

    pupil_slice = (slice(*PUPIL_PATCH_Y), slice(*PUPIL_PATCH_X))
    white_slice = (slice(*WHITE_PATCH_Y), slice(*WHITE_PATCH_X))

    cats = json.loads(CATS_JSON_PATH.read_text())["founder_cats"]

    for cat in cats:
        coat = cat.get("coat", {})
        if not coat:
            print(f"skip {cat['id']}: no coat data")
            continue

        body_color = np.array(hex_to_rgb(coat.get("body_color", "#FFFFFF")), dtype=np.uint8)
        eye_color = np.array(hex_to_rgb(coat.get("eye_color", "#FFFFFF")), dtype=np.uint8)
        pattern = coat.get("pattern", "solid")

        albedo = arr.copy()
        albedo[is_fur] = body_color

        # Eye whites: patched to actual white. Pupils: patched to the
        # founder's eye_color. Both applied last so they win over fur.
        albedo[white_slice] = WHITE_COLOR
        albedo[pupil_slice] = eye_color

        albedo_path = OUTPUT_DIR / f"cat_{cat['id']}_albedo.png"
        Image.fromarray(albedo).save(albedo_path)

        furmask_path = None
        if pattern == "tabby":
            furmask = np.zeros(arr.shape[:2], dtype=np.uint8)
            furmask[is_fur] = 255
            furmask_path = OUTPUT_DIR / f"cat_{cat['id']}_furmask.png"
            Image.fromarray(furmask, mode="L").save(furmask_path)

        print(f"{cat['id']}: fur_px={int(is_fur.sum())} -> {albedo_path.name}"
              + (f", {furmask_path.name}" if furmask_path else ""))


if __name__ == "__main__":
    main()
