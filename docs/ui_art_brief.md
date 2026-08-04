# Catmando UI Style Guide and Production Asset Brief

Status: Milestone 10 information hierarchy and replacement interfaces are locked for usability testing. Commission only after external usability review confirms the hierarchy.

## Stable interface inventory

- Gameplay HUD: day/period, current and next forecast, contextual interaction, community priority, project summary, and one carried-material slot. No default numeric economy panel.
- Village Journal navigation: Community Board, Almanac, investigation guidance, day journal, optional landmark map, settings, save/load, and retained guidance history.
- Modal language: resident dialogue, project choices, investigation, day summary, celebration choice/closing, player-requested hints, and demo acknowledgement.
- Accessibility variants: 85–150% text scale, high-contrast panel treatment, reduced-flash Resonance presentation, subtitles with optional speaker labels, and keyboard/controller glyph switching.
- Resonance uses five unique symbols and motion rhythms in addition to color and sound: open circle/still, one mote/single pulse, two motes/paired pulse, triangle/steady, star/radiating.

## Required production delivery — Batch H

- Nine-slice panels with default and high-contrast borders at all supported UI scales.
- Buttons with normal, hover, pressed, focused, and disabled states; controller focus must never rely on hover.
- Pointer/cursor set and a coherent keyboard/controller input-glyph strategy.
- Monochrome icons for time, clear/rain forecast, interaction, priority, carried material, rumors, finds, patterns, residents, map, settings, save, and hints.
- Almanac frames, founder and three resident text-portrait replacements, optional map landmark marks, and accessibility variants.
- Typography specification including font files, weights, fallback coverage, minimum sizes, line-height rules, and license/attribution documentation.

## Technical contract

Author at 1280 × 720 reference resolution and verify 1600 × 900 and 1920 × 1080. Controls use Godot anchors/containers and Canvas Item stretching. Icons must remain recognizable in monochrome and grayscale. Production assets replace theme resources and icon references without changing gameplay scripts. All placeholder UI nodes carry development-only intent and must be audited before Milestone 12 release cleanup.
