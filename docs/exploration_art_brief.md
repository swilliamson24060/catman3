# Exploration Asset Batch D — Technical Delivery Brief

Milestone 6 locks the gameplay interfaces for Catmando's first exploration and discovery set. Production art must preserve the authored sightlines and stable sockets already exercised by `woodland_route.tscn`, `ancient_ruin.tscn`, and `discovery_site.tscn`.

## Required set

- Woodland vegetation modules for the main route and three branches, including a split stump, bent birch, fallen log, and blue-twine root landmark.
- Ruin modules with a readable low triangular carving at isometric gameplay zoom.
- Weathered garden plaque, rain lens, carved copper gear, dormant seed packet, and triangular clue rubbing.
- Per discovery: world model, inventory/Almanac icon, investigation close-up, inactive VFX anchor, and future activated-material variant.
- Workshop investigation table and small non-military inspection props.
- Parchment-style Almanac illustrations and restrained discovery VFX.

## Locked contracts

- Godot scale is 1 unit = 1 meter; discovery scenes keep their origin on the ground and fit inside a 0.75 m cube unless explicitly approved.
- Each world discovery preserves a root `Node3D`, a focus/VFX socket 0.35 m above the origin, and a separate developer-owned interaction/collision contract.
- Landmarks must remain readable without outlines at the current orthographic camera distance. Marker art is optional assistance shown only after a revisit or explicit help request.
- Unique items never encode gameplay roles in mesh/material names. The data definitions own state and meaning.
- Supply GLB sources, separate collision proxies, material/texture budgets, inactive and future activated variants, and a test-import scene.
- Placeholder category colors and `development_placeholder` metadata remain until replacement validation passes; no military, potion, or universal detector iconography.

Final assets enter an isolated validation scene before replacing placeholders. Verify scale, pivot, material response, bounding boxes, socket names, and readability in rain, morning, sunset, and ruin views.
