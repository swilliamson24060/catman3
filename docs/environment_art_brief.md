# Visual Direction Asset Batch A Brief

Milestone 1 locks the first environment concept-art gate.

## Locked gameplay reference

- Scale: 1 Godot unit = 1 meter; founder collision height 1.25 m.
- Clearing ground footprint: 55 x 55 m (`VillageClearingBootstrap.CLEARING_HALF_EXTENT` x2) -- grown from the original 45 x 45 m to add a 5 m grass buffer ring around the buildable area, so structures stay clear of the tree line. Structures/props still keep to the inner 45 x 45 m (`BUILDABLE_HALF_EXTENT`); the outer 5 m ring is plain ground blending into the boundary treeline. Connected to one narrow woodland route with three short branches.
- Camera: orthographic isometric, 38° downward pitch, four 90° snap angles, 19 m view size, 22 m camera distance.
- Required readable destinations: village center, home edge, workshop edge, abandoned garden, woodland gate, and ruin overlook.
- Occluders must have separable render meshes so trees and buildings can fade without removing collision.
- Style target: warm toy-like woodland diorama, chunky silhouettes, painted surfaces, restrained detail, and soft shadows.

### Ground zones -- texture request superseded, see Milestone 16 status

**Update (2026-08-16): this section's texture request is dropped, not fulfilled.** A tileable texture per zone was produced and wired up (`clearing_grass`/`grassy_center`/`garden_plot`, referenced below), but read as visual noise once tiled across a ground this size, and a follow-up attempt to source replacement textures from the Stylized Nature MegaKit found the kit ships no tileable ground texture at all (its "diffuse" maps are per-model UV atlases for individual rocks/pebbles). Ground is flat per-zone color again (`ZONE_COLORS`, unchanged from the original greybox), with real visual coverage instead coming from a dense real-3D-model grass/vegetation carpet -- see `docs/CATMANDO_REBOOT_PROJECT_PLAN.md`'s Milestone 16 status entry and `scripts/world/nature_props.gd`. If a future art pass still wants a textured ground (soil variation, worn paths, etc.), it should be a hand-authored or licensed tileable texture made for this purpose, not a repurposed prop atlas -- the table below is kept for that footprint/position reference, not as an active request.

The greybox currently tells zones apart with flat placeholder colors only (`village_clearing.gd`'s `ZONE_COLORS`). Six materials were requested -- one base plus five overlaid patches, each with its own footprint and approximate world position (village center at the origin):

| Zone | Footprint | Position (x, z) | Placeholder color reads as | Likely material |
|---|---|---|---|---|
| Clearing base | 55 x 55 m (whole ground) | (0, 0) | mid green | open grass |
| Village center | 13 x 11 m | (0, 0) | warm tan | packed earth / trodden grass |
| Home edge | 12 x 16 m | (-15.5, -5.5) | soft green | grass near the three cottages |
| Workshop edge | 11 x 13 m | (15.5, -4.0) | warm orange-brown | sawdust / worked ground |
| Abandoned garden | 15 x 11 m | (-7.0, 15.0) | dark brown | tilled/overgrown soil |
| Woodland gate path | 6 x 13 m | (0.0, -17.0) | mid brown | dirt path |

Each zone is a flat rectangular overlay, not a blended terrain shader, so tileable textures with soft, blendable edges (or a shared edge-blend approach) will read better than hard-edged tiles. Texel density and maximum texture size aren't fixed anywhere yet -- pick something that reads cleanly at the 19 m orthographic view size above (a ballpark starting point: 128-256 px/meter, i.e. one 1-2K tileable texture per zone).

## Requested deliverables

1. Village-clearing paint-over at gameplay camera scale, showing all five clearing destinations.
2. Woodland-route and ruin-overlook paint-over from at least two snap angles.
3. Palette sheet covering terrain, vegetation, cottages, workshop, garden, ruin, and interaction accents.
4. Material callouts for soil, path, painted wood, stone, foliage, and wet-state compatibility.
5. Scale sheet showing the founder beside a doorway, cottage, workshop, mature tree, garden bed, and ruin stone.
6. Brief season-variant notes for spring through winter without changing silhouettes or navigation footprints.

Concepts should preserve the greybox footprints and sightline intent. Production models are not requested at this gate.
