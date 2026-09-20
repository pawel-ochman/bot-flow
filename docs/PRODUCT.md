# Bot Flow: approved M0–M2 scope

## Purpose

Test whether activating robots in dependency order is understandable and satisfying in a short browser session. Also evaluate an agent-assisted development process with human product ownership and independent review. Documentation and review procedures must work with any model or human contributor.

## Rules

- A rectangular grid contains robots, fixed obstacles and reusable perimeter exit cells.
- Robots have stable IDs, integer coordinates and one fixed cardinal direction.
- A tap activates a robot only if its entire straight route to the first exit is clear.
- Entering any exit removes that robot. Exits are not directional or robot-specific.
- Robots and obstacles block traversal. Leaving the board at an unmarked edge is illegal.
- Rejected activations do not change state or consume lives. No partial movement, pushing, turning or simultaneous movement.
- Ignore robot input during movement. Restart remains available and cancels movement.
- All robots removed means completion. The player explicitly chooses Next; the final level offers replay.
- A reload starts at level 1. Progress persistence is outside this milestone.

## Approved clarification

Legal moves only remove blockers, so they cannot create a deadlock from a solvable state. Multiple legal first moves yield multiple solution orders. The original Level 6 unique-sequence requirement is withdrawn; at M3 it should instead interleave dependencies with several valid solutions.

A fixed obstacle in a robot's travel path makes it permanently unremovable. Level 5 introduces obstacles outside required paths. It does not claim to teach obstacle collision interactively. This intentional limitation was approved before implementation.

## Five levels

1. One robot with a clear upward exit. A subtle pulse invites a tap.
2. Two independent robots, opposite directions.
3. A blocks B: A must leave first.
4. A blocks B, B blocks C.
5. A three-robot chain with permanent obstacles outside all travel paths.

The first five levels have no written gameplay tutorial. Status labels and ordinary button labels are allowed. Directions, exits and blocked feedback must be distinguishable by shapes as well as color.

## Scope and acceptance

M0: Godot project, reproducible headless tests, web export, CI definition, documentation.
M1: one playable level, movement, rejection, completion and restart.
M2: five data-defined levels and navigation, portrait controls, simple audiovisual feedback.

Technical completion requires tests and a served web build. M0's device gate additionally requires a real phone. M2's product gate requires an unfamiliar player to complete level 1 and reach level 5 without explanation. These are separate gates: passing automated tests does not establish player understanding or enjoyment.

Deferred: general solver (M3), levels 6–10 (M3), public deployment and broader polish (M4), measurement (M5), generation (M6), monetization (M7). No accounts, backend, advertising, purchases, analytics platform, currencies or elaborate menus.

## Delivery infrastructure (separately approved 2026-09-20)

CI/CD now covers a shared local build command, PR builds/artifacts, automatic GitHub Pages development deployment from main and intentional itch.io releases from version tags. This supersedes only the earlier deferral of delivery infrastructure; no additional game milestone or player-acceptance claim is implied. See DELIVERY.md for owner setup and release controls.
