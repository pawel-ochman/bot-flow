# Decisions

## 2026-09-19 — Approved scope

Implement M0–M2 after the initial architecture review. Do not implement the complete ten-level specification yet. Product acceptance remains a human gate.

## 2026-09-19 — Monotonic removal rules

Keep successful activation as complete removal. Rejected actions leave state unchanged. This makes every legal action safe on a solvable board; the original Level 6 requirement of multiple legal first moves but only one successful sequence is impossible. Revise Level 6 at M3, rather than adding mechanics to manufacture failure. Minimum successful actions always equals initial robot count and is not a useful difficulty metric.

## 2026-09-19 — Obstacles in Level 5

Obstacles are fixed. A robot pointing through one can never leave. Therefore Level 5 places obstacles off required paths and introduces their appearance only. Collision behavior is covered by impossible test fixtures. Do not silently move an obstacle into a travel path to make this level harder.

## 2026-09-19 — Exit and activation semantics

Exits are reusable perimeter cells, consumed on entry from any travel direction. No entity overlaps at initialization. Unmarked board edges reject. Activation validates the whole route, with one animation at a time and immediate restart. These choices were part of the approved review plan.

## 2026-09-19 — Godot root and version

Put project.godot at repository root so JSON levels are resources without copying between directories. Pin 4.7.2 to match the verified locally available official editor. Use Compatibility, GDScript and single-threaded web templates to minimize browser and hosting constraints.

## 2026-09-19 — Test harness and solver scope

Use a small dependency-free headless runner. Replay per-level solution fixtures through production rules to verify solvability for M2. Defer general solver and solution counting to M3. Avoid a second rules implementation in another language.

## 2026-09-19 — Tool-neutral handoff

Documentation addresses contributors and reviewers by role. It states requirements, commands, evidence and open gates independently of any conversation, model, vendor or editor. Model-specific execution conventions are not repository requirements.

## 2026-09-20 — Reproducible delivery

The owner approved a separate CI/CD scope for the existing five-level game: PR verification, automatic main-to-Pages deployment and deliberate version-tag-to-itch.io releases. This advances delivery infrastructure without adding game features or claiming M3/M4 gameplay completion.

Use one Python standard-library build command on Windows/Linux x86-64. Keep Godot 4.7.2 and its existing single-threaded Web preset. Commit archive checksums; pin action revisions and CI Python/OS versions. Separate Pages into its own workflow so both deployment channels reuse a read-only build workflow without inheriting each other's permissions. Only the production upload step receives the environment-scoped Butler credential; the production job never checks out or executes game/build code. External owner configuration and actual deployment evidence remain distinct from implementation.
