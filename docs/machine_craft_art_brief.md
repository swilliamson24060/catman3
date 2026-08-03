# Asset Batch F — Irrigation Machine and First Craft Set

Milestone 8 locks one communal machine and one craft family. Production art may replace the placeholder presentation without changing its data, scene, socket, or state contracts.

## Scale and scene contract

- Godot scale: 1 unit = 1 meter; ground-contact origin at machine center.
- Approximate installed envelope: 2.8 m wide × 1.6 m deep × 1.6 m tall, readable from the locked isometric camera.
- Preserve named sockets: `OperatorSocket`, `InputSocket`, `OutputSocket`, and `WaterVFXSocket`.
- Keep interaction clearance in front of the machine and a readable approach for Pip.
- Separate collision proxies from animated gears, cloth, and water effects.

## Required machine states

1. `incomplete`: recognizable loose irrigation assembly in the empty workshop slot.
2. `installed_idle`: repaired communal device, water routing visible, no implied passive production.
3. `operating`: flowers/plant color at the input, gear movement and water at work, cloth visibly emerging.
4. `resonant`: restrained First Bloom response and an obvious invitation to make dyes.
5. `maintenance`: stopped or misaligned gear with a readable Pip repair pose and tool contact.

Deliver moving gear, input tray, cloth output, water emitter, restrained Resonance emitter, and operator interaction animation sockets as separate controllable elements. Animation names and durations must not encode gameplay completion.

## First craft set

Provide three recolorable cloth outputs matching the locked craft IDs: Sunrise cloth, Rainpetal cloth, and Bloomberry cloth. Each needs a world model and future UI icon, consistent pivots, and a shared material setup. Colors must remain distinguishable by value/pattern as well as hue for the Milestone 10 accessibility pass.

## Validation gate

Import into an isolated validation scene first. Verify scale, pivots, state switching, socket positions, animation names, water bounds, material count, and silhouette at minimum/maximum gameplay zoom. Do not remove placeholders until all five states and all three cloth outputs resolve through the existing scene/data references.
