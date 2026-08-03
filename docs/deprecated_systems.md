# Deprecated Prototype Systems

Milestone 0 keeps the legacy prototype recoverable at `res://scenes/world/main.tscn` while the development main scene moves to `res://scenes/world/village_clearing.tscn`. The systems below remain available only for legacy compatibility and regression tests. New reboot code must not add dependencies on them.

| Deprecated system | Current compatibility reason | Removal criterion |
|---|---|---|
| Cheese salaries, salary strikes, recurring upkeep | Legacy roster/save replay | Vertical slice save fixtures no longer require legacy economy fields and legacy regression build is archived. |
| Generic recruitment and housing capacity | `AnimalManager` legacy roster | Three named residents spawn and restore through `ResidentManager`, with migrated fixtures passing. |
| Right-click orders / laser pointer | Legacy prototype controls | Community Board priority flow passes its playable tests. |
| Catnip drift speed modifiers | Legacy production tests | No reboot service or save fixture references the modifier. |
| Dust Bunny economy rewards | Legacy scene content | Authored discovery/resource loop replaces random reward spawning. |
| Whisker Radar | Legacy HUD | Almanac rumor/hint ladder passes onboarding tests. |
| Cat-stack scaffolding | Legacy construction mechanic | Community-project contributions cover construction feedback. |
| Dream-mode production prediction | Legacy simulation debug | Calendar debug controls and day ending cover test acceleration. |
| Cheese Vault and achievement unlock progression | Legacy content graph | Almanac/community milestones own reboot unlocks and migrations are validated. |
| Undersea and Space Mice expansions | Loader regression coverage | Core vertical slice ships and expansion authoring has a reboot contract. |
| 70×70 uniform prototype field | Recoverable legacy main scene | Handcrafted clearing and woodland route pass Milestone 1 tests. |
| Exact-offset Architectural Resonance | Legacy discoveries and bonuses | Tolerant Seasonal Resonance passes Milestone 7 tests and old saves have a reviewed conversion. |
| Military/conflict asset references | Third-party asset library only | Release asset audit confirms no live scene/data references; archive/delete separately. |

Do not remove a deprecated autoload merely because the reboot scene does not use it. Removal happens in Milestone 12 only after live-reference inspection, save migration validation, and the complete vertical-slice regression gate.
