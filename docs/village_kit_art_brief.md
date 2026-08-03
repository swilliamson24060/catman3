# Village Kit Asset Batch C — Production Brief

Milestone 5 locks the community-garden footprint and interaction contracts sufficiently to request the modular village kit. These assets replace development placeholders; they must not add gameplay logic or alter authored IDs.

## Shared technical contract

- Godot scale is 1 unit = 1 meter. Ground contact is local Y = 0; +Y is up and -Z is forward.
- Deliver GLB source plus an isolated Godot import-validation scene for each asset family.
- Use chunky, toy-like woodland silhouettes readable through the locked orthographic camera at 19 m size.
- Keep collision as separate simple proxies. Do not derive gameplay state from mesh or material names.
- Target one primary material plus one accent material per modular prop where practical; painted surfaces should remain readable in morning, rain, and evening lighting.
- Mark final interaction, carry, contribution, door, and VFX sockets with stable `Marker3D` nodes.

## Required environment pieces

- Three cottage variants fitting the existing 4.2 × 4.2 m plots, with a doorway appropriate for the 1.05 m resident capsule and a readable stoop/social socket.
- One workshop fitting the 6 × 5 m footprint, with porch social slots and visible tool/work sockets.
- Modular path, low fence, gate, sign, bench, table, mug, tool, crate, reclaimed-wood, smooth-stone, and common-seed props.

## Community garden

- Overall authored zone: 15 × 11 m, centered at the existing abandoned-garden destination.
- Preserve `PhasePresentations`, `ContributionSlots/PlayerSlot`, `ResidentSlotA`, `ResidentSlotB`, and the interaction-anchor meaning from `scenes/projects/community_project.tscn`.
- Deliver five mutually replaceable garden variants sharing the same origin and bounding footprint:
  1. abandoned/debris;
  2. cleared beds under repair;
  3. repaired beds with incomplete irrigation;
  4. planted with ordinary local flowers;
  5. restored and celebration-ready with ordinary flowers.
- Keep rare flower colors and Resonance materials out of Batch C; those remain locked behind The First Bloom and Asset Batch E.
- Provide clean collision proxies, camera-distance screenshots, triangle/material counts, texture sizes, and LOD guidance.

No placeholder is removed until its replacement passes scale, pivot, material, socket, collision, and camera-readability validation.
