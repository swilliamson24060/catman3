# Milestone 1 Placeholder Contract

## Milestone 6 exploration contracts

- `scenes/discoveries/discovery_site.tscn` is the replacement seam for every authored find: ground origin, stable interaction anchor, and a 0.35 m focus/VFX point.
- Cyan, copper, gold, purple, and stone placeholders distinguish discovery categories only; gameplay identity comes from `data/discoveries.json`.
- Woodland landmarks lead before optional markers. A marker becomes visible only after a revisit/help request.
- The workshop investigation table and Almanac panels are development placeholders with production dimensions documented in `docs/exploration_art_brief.md`.

## Milestone 7 Resonance contracts

- `scenes/resonance/resonance_plinth.tscn` preserves ground origin, a 0.9 m `ComponentSlot`, 1.1 m `VFXSocket`, and a separate interaction anchor.
- `scenes/resonance/resonance_site.tscn` owns replaceable feedback lines, center pulse, three-tone audio seam, and First Bloom flower presentation.
- Cyan lens, copper wheel, and gold seed packet are silhouette placeholders only; component roles are data-driven and remain hidden in player-facing UI.
- Tier colors are development shorthand backed by distinct mote/line/pulse behavior. Production accessibility treatment remains scheduled for Milestone 10.

## Milestone 8 machine and craft contracts

- `scenes/machines/irrigation_machine.tscn` is the only active machine in the slice and keeps a ground-contact origin plus stable `OperatorSocket`, `InputSocket`, `OutputSocket`, and `WaterVFXSocket` nodes.
- The modular cyan box, copper gear, particles, tray, status label, and cloth blocks are development placeholders. Machine identity, state, operator, and craft family come from `data/community_machines.json` and `data/crafts.json`, never from color or mesh names.
- Replacements must preserve the incomplete, installed-idle, operating, Resonant, and maintenance presentations. Input, moving-work, and output beats must remain visibly distinct at gameplay zoom.
- Cloth swatches are persistent evidence of completed crafts, not inventory quantities or production-rate indicators. The slice supports only First Bloom natural dyes.

## Milestone 9 celebration contracts

- `scenes/events/first_bloom_celebration.tscn` owns three stable `ContributionSlots`, separate resident contribution props, two mutually exclusive player-choice presentations, gathering lights, and a status-label seam.
- Flower cylinders, light orbs, food blocks, story cards, and bunting strips are development placeholders. Resident IDs, contribution order, choices, and closing dialogue come from `data/village_events.json`; colors and node names never decide event progress.
- Production replacements preserve Mara's flower-table beat, Pip's light-hanging beat, Elowen's story-card beat, the `sunrise_bunting` and `firefly_lanterns` variants, and unobstructed four-participant garden-table clearance.
- Text initials are temporary portrait substitutes. The procedural four-note gathering motif is a development-only audio layer behind the event-state transition.

## Milestone 10 UI contracts

- Theme boxes, text labels, text portraits, and monochrome Resonance symbols are development-only placeholders behind `RebootUIShell` and the existing modal interfaces.
- The gameplay HUD and Village Journal use anchored containers from a 1280 × 720 reference and must remain readable at every larger supported viewport.
- Five Resonance states always combine a unique word, symbol, and motion description; production color and audio may reinforce but never replace those channels.
- Batch H may replace theme resources, icons, glyphs, frames, portraits, and typography without changing input actions, service state, or screen contracts.

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

## Milestone 3 resident contract

- Mara, Pip, and Elowen reuse the cube-pet bunny model at a locked 0.72 scene scale, with a 0.32 m radius / 1.05 m height collision capsule and ground-contact origin.
- Each resident scene exposes stable `SpeechBubbleAnchor`, `CarriedItemSocket`, `InteractionAnchor`, `NavigationAgent3D`, and `AnimationPlayer` nodes. Final character assets must preserve those paths and socket meanings.
- Loud coral, blue, and violet material overrides communicate identity during greybox testing; color never drives resident logic.
- Movement and activity use procedural bob/lean placeholders behind the animation interface. Final clips replace them with `idle`, `walk`, `talk`, `carry`, `work`, and `celebrate` animations.
- Debug score labels are development-only and disabled by default. The Resident Almanac is the player-facing locator; residents receive no permanent overhead marker.
- Text-only resident names and aspiration dialogue stand in for portrait cards and expressions.

No resident placeholder may ship without a reviewed replacement or explicit approval.

## Milestone 4 social-place contract

- Social places use `scenes/social/social_place.tscn` with stable `Presentation` and `Slots` children. Final benches, tables, porches, stoops, mugs, tools, and celebration props may replace presentation children without changing the place ID, capacity, activity IDs, or reservation API.
- Slot transforms are the authoritative non-overlapping participant positions. Replacement props must preserve enough clearance and sightlines for every authored slot.
- `ActivityBubble` is a development-only icon label that communicates conversation, meal, collaboration, visit, celebration, or future enabled activity. Final animation and VFX may replace it while retaining the resident activity-state interface.
- Placeholder colors and prop styles communicate place identity only; they never determine compatibility, bond rewards, activity availability, or resident decisions.
- Relationship changes are intentionally surfaced through visits, activity animation, dialogue memories, journal summaries, and transient HUD feedback before any numerical bond display.

Final social-place art remains gated until capacities, slot spacing, and camera readability have been tested during the Community Garden milestone. No Milestone 4 social placeholder may ship without a reviewed replacement or explicit approval.

## Milestone 5 community-project contract

- `scenes/projects/community_project.tscn` owns the stable project root, five ordered `PhasePresentations`, and `ContributionSlots` for founder and residents. Final garden states replace presentation children without changing project ID, phase order, origin, footprint, slots, or interaction anchor.
- The authored garden zone remains 15 × 11 m. Contribution props must preserve clear approach paths and visibility from the locked camera.
- Reclaimed wood, smooth stone, and common seed piles are development-only material-source placeholders. Their colors communicate identity but never determine inventory or project logic.
- The founder's `CarriedItemSocket` and residents' existing carried-item socket remain stable replacement seams. A visible cube and icon bubbles currently stand in for carry and five contribution actions.
- The restored placeholder uses ordinary local flowers only. Rare colors, Resonance glow, special seeds, and First Bloom effects remain explicitly gated to Milestones 6–7.

Village Kit Asset Batch C requirements are recorded in `docs/village_kit_art_brief.md`. No Milestone 5 project placeholder may ship without a reviewed replacement or explicit approval.
