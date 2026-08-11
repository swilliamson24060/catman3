# Character Asset Batch B — Founder and Three Residents

Request this batch after Milestone 3 routine readability is approved. Gameplay contracts are now locked; names remain subject to narrative review.

## Shared production contract

- Godot scale: 1 unit = 1 meter. Resident greybox capsule is 1.05 m tall with 0.32 m radius; delivered models are applied at scale 1.0 (`residents/resident_appearance.gd`'s `MODEL_SCALE`), so new deliveries should already be sized to the project's real-world meter scale rather than needing a corrective multiplier.
- Origin at ground contact; forward is Godot -Z; no root motion.
- Preserve named sockets for speech/VFX above the head, carried items in front of the torso, and contextual interaction.
- Deliver GLB models with separate developer-owned collision proxies and materials compatible with the project palette.
- Six looping/one-shot core clips per character: `idle`, `walk`, `talk`, `carry`, `work`, `celebrate`. Include loop rules and 30 FPS source timing.
- Silhouettes, specialty props, and posture must remain readable at the locked 19 m orthographic camera size.

## Required concepts per character

- Founder cat: turnaround, interaction and tool-use poses, palette, expression sheet, bust portrait.
- Mara, gardener: turnaround, patient/observant posture, garden motif, palette, expression sheet, home motif, bust portrait.
- Pip, tinkerer/builder: turnaround, inventive/practical posture, tool motif, palette, expression sheet, home motif, bust portrait.
- Elowen, historian: turnaround, curious/thoughtful posture, notebook or ruin motif, palette, expression sheet, home motif, bust portrait.

## Validation delivery

Provide one test GLB first. It will be imported into an isolated Godot validation scene to verify scale, ground pivot, -Z facing, socket positions, material count, bounding box, animation names, and camera-distance readability before production models replace placeholders.
