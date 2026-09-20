# Bot Flow

A small browser puzzle: tap robots in dependency order to clear a factory floor. Five introductory levels, no written gameplay tutorial, no backend.

The approved implementation scope is **M0–M2**, not the full commercial roadmap. See [product rules](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), [decisions](docs/DECISIONS.md), [review guide](docs/REVIEW.md) and [verification/experiment log](docs/LEARNINGS.md). These documents are self-contained and apply to any human or model reviewing the project.

## Requirements

- **Godot 4.7.2 standard edition**, matching official export templates. No .NET edition or plugins required.
- Git and Python 3.12+ for the shared build command (no Python packages needed).
- A browser with WebAssembly and WebGL 2.0.

Obtain the editor and `Godot_v4.7.2-stable_export_templates.tpz` from the [official release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable). The commands below use `godot` for the editor executable. On Windows, use the console executable; if it is not on PATH, invoke its absolute path with PowerShell's `&` operator.

## Run and verify

From the repository root:

```text
godot --headless --path . --import
godot --headless --path . --script tests/run.gd
godot --headless --path . --script tools/validate_levels.gd
godot --path .
```

Alternatively open `project.godot` in the editor and press Run. The tests cover deterministic movement, rejection, exits, schema validation, level solution replay and controller restart/input behavior. Read console output as well as exit codes: any `SCRIPT ERROR:` or `ERROR:` is a failure. CI enforces both.

## Build and delivery

With Git and Python 3.12+ on Windows/Linux x86-64, run:

```text
python scripts/build_web.py
```

This downloads and verifies the pinned official Godot 4.7.2 tools, runs all required checks, exports the existing Web preset and verifies the output in `build/web`. It needs no production credentials. See [delivery documentation](docs/DELIVERY.md) for prerequisites, failure diagnostics, owner setup and release steps.

```text
python -m http.server 8060 --bind 127.0.0.1 --directory build/web
```

Open [the local game](http://127.0.0.1:8060). Deploy the whole directory; do not open the HTML directly as a local file.

PRs and feature branches build and upload a downloadable artifact. Main calls the same build and automatically deploys to GitHub Pages after success. Version tags intentionally rebuild and publish to itch.io through a protected production environment. External repository settings and credentials must be configured before deployments work; see [DELIVERY.md](docs/DELIVERY.md). Local checks do not prove a hosted CI run or successful public release.

## Browser and player acceptance

Smoke-test a served export: clear all five levels; try blocked robots; restart during movement; tap repeatedly; mute/unmute; resize; background and resume the tab. Check desktop Chrome/Firefox and real Android Chrome/iOS Safari. A portrait viewport emulation does not replace a real phone test. Sound must be checked by listening on the target device.

The first five levels teach through arrows, exits, motion and rejection feedback. An unfamiliar person's unaided playthrough is still required before accepting M2's learning goal. Use `docs/REVIEW.md` for a reproducible review and playtest checklist.

## Assets and limits

Robot, obstacle and floor shapes are simple drawing code. Four short WAV effects were synthesized specifically for this prototype; there are no external art, font or audio assets. Progress is session-only. There are no lives, turns, hints, solver UI, tracking or monetization.
