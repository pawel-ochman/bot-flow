# Architecture

## Runtime and data

Godot 4.7.2 standard edition, GDScript, Compatibility renderer, single-threaded web export. One main scene. No plugins or third-party runtime dependencies.

`game/core/level_data.gd` parses JSON and validates shape, coordinates, IDs, directions, perimeter exits and disjoint initial occupancy. Version 1 permits board dimensions 2–12 in each axis; shipped boards are 5×5. Unknown fields are ignored for descriptive metadata. Validation is not a solvability claim.

`game/core/rules.gd` operates on validated dictionaries. A state is a deep copy of a level; accepted moves remove one robot from that copy. `inspect_action` returns a deterministic route or rejection reason without mutation. `apply_action` mutates only on success. `valid_actions`, `is_complete` and `is_stuck` share the same route rules. `is_stuck` detects no immediate moves; eventual unsolvability search is deferred to M3.

`game/presentation/main.gd` owns the active level, state, controls, audio players and animation. It applies the accepted move once, then animates the removed robot. Input stays locked until completion. Restart kills the tween, stops sounds and increments a generation counter to invalidate stale callbacks.

`game/presentation/board.gd` draws simple grid/robot/exit/obstacle shapes and maps pointer positions to cells. Drawing and hit testing share one layout calculation. Browser touch is converted to mouse once; there is no second touch activation path. Rules never inspect visuals, physics or timers.

## Level and test boundaries

Published JSON lives in `levels/`, named by stable ID. The web export explicitly includes these files. Expected solution sequences live only in test fixtures. Validation scans every published JSON rather than relying on the five-level UI limit. Adding a playable level currently also requires changing `LEVEL_COUNT` in the controller; dynamic content catalogs are unnecessary for M2.

The headless test runner uses the same production rules, then loads the presentation scene to exercise restart/input races. It uses explicit checks and an exit status, not removable release assertions. CI additionally rejects engine error lines because some Godot errors do not set a failing process status.

## Export

The project root is the Godot resource root. Downloaded engine/templates are ignored in `.tools/`; `tools/setup_templates.py` verifies the template version and extracts only web templates. Export uses project-local templates for reproducibility. `build/web/` is a generated artifact served with HTTP locally or HTTPS externally.

No persistence, services, PWA, threads, custom engine build, GDExtensions or physics simulation. Sound is four original prerecorded WAV files, compatible with web sample playback; generation is not performed at runtime.

## References

- [Godot web export constraints](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html)
- [Godot command-line reference](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)

Stable documentation can change. The editor/template version is deliberately pinned; upgrades require tests and a browser check.

## Delivery automation

`scripts/build_web.py` is the shared local/CI entry point. `tools/setup_toolchain.py` reads checksum-locked official downloads from `tools/toolchain.json`; `tools/verify_web_build.py` validates the exported artifact. The existing Web preset is unchanged. No global installation or production credential is needed to build.

`ci.yml` provides read-only builds for PRs/branches and reusable calls. `deploy-pages.yml` builds main and deploys that run's exact artifact. `publish-itch.yml` checks release tags against main history, calls the same build workflow, and uploads via official Butler in a separate environment-protected job. Pages and production permissions are job-scoped. Settings, secret boundaries, pin provenance and verification limits are documented in DELIVERY.md.
