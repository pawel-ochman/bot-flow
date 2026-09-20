# Independent review guide

Read PRODUCT.md, ARCHITECTURE.md and DECISIONS.md first. Use README.md to reproduce tests and export. Reviewers may use any model or work manually; no prior conversation is needed.

Check these invariants:

- Illegal actions leave all state unchanged; successful actions remove exactly one robot.
- Each path stops at its first exit, blocker or unmarked boundary.
- Level data cannot alias mutable runtime state.
- Restart during movement cannot trigger completion or remove a robot from the new state.
- Input during movement cannot activate another robot.
- Every published level is validated and completed by its fixture in CI.
- JSON and sound resources are present in the served web export.
- The first five levels contain no written gameplay instructions.
- There is no out-of-scope infrastructure or future mechanic hidden in abstractions.
- Documented evidence distinguishes local tests, hosted CI, browser checks, real-device checks and player observation.

Report each actionable finding with severity, file/line, reproduction, expected behavior and observed behavior. Separate defects from optional preferences. Do not rewrite code during a read-only review. The implementer records fixes and reruns relevant checks; a human makes the final gameplay decision.

For the player test, give the link to someone unfamiliar with the game without explaining controls. Observe first action, rejected taps, level 1 completion, level 5 reach, restarts and requests for help. Record approximate session duration and whether they voluntarily replay. Do not add an analytics platform for this test.
