# Contributor instructions

These instructions apply equally to human contributors and automated coding or review tools. No particular model, vendor, editor, or conversation history is required.

1. Read `docs/PRODUCT.md` before product changes and `docs/ARCHITECTURE.md` before structural changes.
2. Implement only the approved milestone. Prefer the simplest solution; do not build infrastructure for hypothetical needs.
3. Keep rules deterministic and independent of presentation. Update rule tests when behavior changes.
4. Run the commands in README.md. Report what actually passed and distinguish untested acceptance criteria.
5. Never change level semantics without documenting the reason in `docs/DECISIONS.md`.
6. Record meaningful architectural decisions and unresolved ambiguities. Do not silently invent behavior.
7. Review generated code to the same standard as manually written code.
8. Record meaningful tasks, review findings, rework and human intervention in `docs/LEARNINGS.md`. Do not invent human time estimates.
9. Documentation must be self-contained and model-agnostic. Describe roles (implementer, reviewer), not model-specific capabilities or prompts.
10. An independent reviewer should check correctness, scope, test coverage and architectural drift before acceptance. Gameplay acceptance belongs to a human player.
