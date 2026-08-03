# Milestone 1 Placeholder Contract

All Milestone 1 geometry is development-only greybox content. Runtime-created nodes carry `development_placeholder=true`; reusable scene assets carry `_development_placeholder` metadata.

- Godot scale is 1 unit = 1 meter.
- Founder collision contract: 0.38 m capsule radius, 1.25 m total height, origin at ground contact.
- Building placeholders keep their ground-centered footprint and are replaceable through scene instances in later milestones.
- Trees use a trunk collision proxy on layer 1 plus the occlusion layer bit. Replacement trees must keep a comparable trunk proxy and expose descendant `MeshInstance3D` nodes for fading.
- Interaction anchors use `scenes/world/interaction_anchor.tscn`; final icons may replace presentation without changing `anchor_id`, prompt, focus, or activation behavior.
- Terrain colors communicate authored zones but contain no gameplay state.
- Ambience zones use `scenes/world/ambience_zone.tscn`; authored audio replaces the procedural tone without changing zone radius or identity.

No placeholder may ship without a reviewed replacement or explicit approval.

## Milestone 2 time and weather contract

- Period presentation is owned by `DayEnvironmentController`: replacement skies and lighting must preserve the four `morning`, `afternoon`, `evening`, and `night` identifiers.
- `WeatherPresentation/Rain`, `SunDisc`, and `MoonDisc` are development-only procedural/primitive placeholders. Final resources replace their materials or child presentation without changing these stable node paths.
- Rain communicates forecast state only; it does not own calendar or gameplay state.
- Ambience replacements keep the `AmbienceZone.set_period_mix(period_id)` seam so authored loops can respond to the calendar without new schedule logic.
- The calendar HUD is a debug/readability aid. Final UI may replace its styling while retaining the current period, three-day forecast, and home end-day affordance.

The sky gradient specification, rain particles, wet-surface treatment, and period lighting reference remain gated until the Milestone 1 world palette is approved.
