# Build and delivery

This guide is for any human contributor or coding/review tool. Gameplay remains M0–M2; this separately approved task adds delivery infrastructure only.

## Local build

Requirements: Git, Python 3.12 or newer, Windows or Linux on x86-64, and outbound HTTPS access to official Godot release downloads on the first run. CI uses Python 3.12.12 and Ubuntu 24.04. No production credentials, global Godot installation, package manager, Docker or Python packages are needed.

From the repository root:

```text
python scripts/build_web.py
```

The command:

1. Refuses linked/junction output paths and cleans only `build/web`.
2. Downloads the pinned Godot 4.7.2 editor and templates into `.tools/downloads`, checks SHA-256 and extracts project-local tools. Cached archives are reverified on every run. It never silently upgrades the engine.
3. Checks the actual engine version, runs delivery-tool tests, imports the project, runs the existing game tests and validates every published level against its solution fixture.
4. Exports the existing `Web` preset and checks the HTML/JS/WASM/PCK files, binary signatures, loader sizes, relative resources and audio worklets.
5. Writes `build/web/build-info.json` with the commit (null before the first commit), dirty-worktree flag, tool versions and asset hashes. Stage logs stay in `build/`, outside the deployable directory.

Any failing command, timeout, Godot `ERROR:`/`SCRIPT ERROR:`, checksum mismatch or invalid artifact exits nonzero. Files left by a failed export are not a successful build and are never uploaded by CI. The command replaces the local web output, so stop a local preview server if it holds files open.

Serve the result:

```text
python -m http.server 8060 --bind 127.0.0.1 --directory build/web
```

Open [the local game](http://127.0.0.1:8060). For fast checks after setup, run the existing Godot test/validator commands from README.md, or run just the delivery-tool tests:

```text
python -m unittest discover -s tests -p test_build_tools.py
```

The manual template extractor remains available: `python tools/setup_templates.py path/to/Godot_v4.7.2-stable_export_templates.tpz`. It now checks the same committed checksum. macOS/ARM bootstrap is not included; this task adds no new export targets.

## Pull requests and development deployment

- `ci.yml`: pull requests, non-main branch pushes, manual checks, and reusable workflow calls. Uses a read-only token; no deployment environment or production secrets. Runs the exact local build command and uploads `bot-flow-web-<commit>` for 14 days. Failed builds upload diagnostic logs instead.
- `deploy-pages.yml`: pushes to `main` call that same CI workflow, then deploy its exact artifact ID through official Pages actions. The deploy job has only Pages/OIDC write permissions and does not execute artifact code. Concurrency avoids overlapping Pages deployment runs.
- A manual CI run only verifies/builds; it does not publish. Main is handled by the Pages workflow to avoid duplicate main builds.
- No cross-run artifact search, privileged `workflow_run`, `pull_request_target`, secret inheritance, shared executable caches or repository write tokens are used.

Download the artifact from the workflow run's summary. It contains the entire web directory; deploy all its files without renaming them. The Godot single-threaded preset is retained, so custom cross-origin-isolation headers are unnecessary. Relative resource checks support GitHub project Pages URLs below a repository subpath.

## GitHub owner setup

These settings are not created by repository YAML and have not been configured by the implementer:

1. Create/connect the intended GitHub repository, commit the project, and push `main`. Add the actual `origin` URL yourself; none is assumed.
2. Enable Actions. Allow the pinned official `actions/*` actions and reusable workflows in repository/organization policy. Keep default workflow permissions read-only.
3. Settings → Pages → Build and deployment → Source: **GitHub Actions**. Confirm Pages is available for the repository visibility/account plan.
4. Create/configure `github-pages`, permitting deployment only from the **branch** `main`. Leave manual approval off if development deployments should be automatic.
5. Protect `main`: require pull requests, review and the PR `Test and build Web` check after the first CI run. Disallow direct bypass for ordinary contributors. Require trusted review of `.github/workflows/` and build-tool changes.
6. Protect `v*` tags with a repository ruleset: only trusted release maintainers may create them; restrict update/deletion. Treat a release tag as authorization to publish that commit. The workflow additionally requires a version tag on `main` history.
7. Create `production`. Set deployment restrictions to **tags** matching `v*`, with no branch allowance. Store `BUTLER_API_KEY` only here, never as a general repository secret. This restriction prevents even an edited PR workflow from obtaining it. Enable required reviewers and prevent self-review where your GitHub plan supports it; the workflow needs no redesign when approval is enabled.
8. Set production environment variables `ITCH_TARGET` to `username/project` and `ITCH_CHANNEL` to a channel such as `html5`. These are non-secret routing configuration; do not put credentials in variables.

No production secret should exist at repository or organization scope for this project. Environment protection and tag permissions are part of the security boundary, not optional substitutes for workflow checks.

## itch.io owner setup

Create the target itch.io project and obtain a Butler upload credential using the official `butler login` flow on your own machine. Store the resulting credential as production's `BUTLER_API_KEY`; do not commit the credential file or paste it into logs. Current authentication instructions are in the [official Butler manual](https://itch.io/docs/butler/login.html).

Configure the project as HTML. After the first upload, mark the uploaded channel **This file will be played in the browser**, save the project settings, configure the embed size/mobile options, and choose the project's intended visibility. Butler uploads builds; it does not replace this first-time project configuration. See [itch.io HTML publishing instructions](https://itch.io/docs/butler/pushing.html).

## Intentional release

First merge the reviewed change into `main`, confirm its CI/Pages run succeeds, and verify the game. Then, from an up-to-date clean checkout:

```text
git switch main
git pull --ff-only origin main
git tag -a v0.1.0 -m "Bot Flow 0.1.0"
git push origin v0.1.0
```

`publish-itch.yml` accepts `vMAJOR.MINOR.PATCH` (optionally a hyphenated prerelease suffix), verifies that the tagged commit belongs to main history, and rebuilds/tests that exact source without production secrets. A separate `production` job downloads only that run's verified artifact by ID, obtains checksum-pinned official Butler 15.31.0, and runs `butler push` with the tag as `--userversion`.

Approve the environment deployment if configured. Verify the workflow and itch.io page afterwards. A failed upload fails the workflow; never interpret an artifact-only success as a published release. Investigate failed uploads before rerunning: a network failure can occur after the service has accepted an upload. Rerunning or publishing an older tag can replace the channel's current build; tags are intentional releases, not a chronological rollback guard. Concurrency prevents overlapping uploads but is not a permanent release queue—do not push batches of release tags.

## Pins and maintenance

Godot archive SHA-256 values in `tools/toolchain.json` were checked against the official [4.7.2 release asset metadata](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable). The Butler archive checksum in `publish-itch.yml` was calculated from the exact versioned official HTTPS download, following [Butler's automation download instructions](https://itch.io/docs/butler/installing.html). All external actions use full commit SHAs with readable release comments. The Pages upload action's own upload dependency is also SHA-pinned in the selected upstream revision.

Update pins in a reviewed change; verify new downloads and run tests, a clean build and browser checks. Do not substitute `latest` or skip hash failures. Hosted OS images still receive updates: this is a repeatable, version-controlled build process, not a claim of a fully hermetic or byte-identical build environment. No self-hosted runner is assumed.

## Verification boundaries

Local checks cannot prove a hosted Actions run or external deployment. No GitHub remote is configured yet. Repository owner settings, an actual PR workflow, main Pages deployment and an intentional itch.io release must be verified once the external configuration exists. Real-device and unfamiliar-player acceptance remain separate from build validation. See LEARNINGS.md for executed checks and independent review results.
