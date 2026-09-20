# Verification and development experiment log

This record separates implementation evidence from acceptance. It is intended for any human or model reviewer; no original conversation is needed.

## Task: M0–M2 foundation and five-level prototype

- Date: 2026-09-19.
- Agent/role: implementation agent; separate read-only review agent. Model identity is not a prerequisite for reproduction or review.
- Human preparation time: not measured.
- Human intervention: supplied specification, reviewed minimal architecture, approved rule clarifications and requested model-agnostic documentation. Authorized required local tooling/network access.
- Execution attempts: initial implementation followed by automated verification and browser export checks; detailed results below.
- Scope: rules, five JSON levels, presentation, sounds, test harness, validator, web export, CI definition and contributor documentation.
- Review findings/rework: independent review found a missing final redraw after rejection and narrowing coordinates before bounds checking. Both fixed; tests now include oversized coordinates. Reviewer also requested a meaningful second-robot input-lock test; added. Follow-up review confirmed the fixes and documentation approach, with no additional actionable code finding in those changes.
- Outcome: M0–M2 implementation delivered locally; automated checks and web export pass. Human gameplay and real-device acceptance remain open.

## Evidence

- Verified local editor: 4.7.2.stable.official.ed1daf0bf.
- Initial test run: 74 checks, zero assertion failures; shutdown reported a still-playing audio resource. Rework: keep controller tests muted because they test state/animation, not audio mixing. Browser sound remains a separate acceptance check.
- Final automated run: 78 checks, zero failures, no engine errors. All five published levels validated and their solutions replayed successfully. Restart-during-animation and second-robot input-lock checks pass.
- Web export succeeds with all five JSON levels and all four sound resources in the pack. Initial browser check exposed that custom `web_release.zip` is threaded despite the disabled preset option. Changed extraction and preset to explicit `web_nothreads_*` templates; rebuilt and confirmed browser startup without isolation headers.
- Browser inspection exposed a completion-layout overflow and missing decorative button glyphs in the default font. Layout now accounts for visible controls; button labels use ordinary text.
- Served build verified in the desktop in-app browser, including a 390×844 portrait viewport. Fresh level 1 loaded, robot moved and completion appeared; Next loaded level 2; a rapid second-robot tap was ignored while the first robot moved. Browser warning/error log was empty for this corrected build. An observed separate session reached level 5 completion, but it is not counted as an unfamiliar-player study.
- Additional browser checks: completed level 2; on level 3 a blocked activation highlighted both robot and blocker, then cleared without another interaction; restart during a legal move restored both original robots. These checks corroborate the timer and restart fixes.
- Git repository initialized locally on `main`. No remote, commit, pull request or hosted CI run has been created.

## Open acceptance gates

- Hosted CI execution requires a GitHub repository and actual workflow run.
- Real-phone testing, audible sound verification, and an unfamiliar player's unaided playthrough have not been performed.
- Public deployment, ten levels and the general solver are later milestones, not incomplete M2 implementation tasks.

## Task: reproducible CI/CD (2026-09-20)

- Agent/role: implementation agent, followed by an independent read-only reviewer; no model-specific workflow dependency.
- Human preparation time: not measured.
- Human intervention: supplied delivery specification, approved the inspection/implementation plan, authorized required network and tooling access. No production credential was requested or read.
- Scope: one shared Python build command, locked official Godot downloads, build-output verification, read-only reusable CI, main-only Pages workflow, tag-only environment-protected Butler workflow and model-agnostic owner documentation.
- Execution attempts: implementation, delivery failure-path tests, workflow static validation, full Windows build, then a cache-free source-copy build. Initial sandbox restrictions prevented temporary-directory access; rerunning with the necessary access passed. No game rules or levels changed.
- Evidence: final shared-command run also passed after prerequisite/metadata corrections. 15 delivery-tool tests passed, all 78 existing game checks passed, all five level fixtures validated, Web release export and static artifact verification passed. A separate source copy started without `.godot`, `.tools` or `build`, fetched verified official downloads, imported all assets and passed the same pipeline (14 delivery tests at that point; the timeout regression test was added afterwards).
- Tooling verification: actionlint 1.7.12 passed all workflows. Its locally downloaded official release archive was checksum-verified; it is not an added workflow action or build dependency. The pinned Linux Butler archive was verified and `butler version` reported 15.31.0; `butler push --help` confirmed the intended options. No login or upload occurred.
- Platform boundary: local builds used Windows/Python 3.12.6. Existing WSL is Ubuntu 22.04/Python 3.10, so the full Linux build was not run there. CI explicitly requests Ubuntu 24.04/Python 3.12.12. A cache-free Windows build is evidence for bootstrap/import completeness, not evidence of a hosted Linux CI run.
- Review findings/rework: independent static review found no blocking correctness or security issue. It identified missing captured diagnostics on subprocess timeout; fixed and covered by a regression test. Follow-up review confirmed the timeout fix, Git-root provenance check and owner security instructions with no actionable issue. Independent test execution was blocked by sandbox permissions, so test evidence above comes from the implementation run. Hosted execution remains unverified.
- External gates: no GitHub remote/commits, hosted PR CI, uploaded Actions artifact, configured Pages environment/site, production environment/credential or itch.io release exists for this repository yet. DELIVERY.md lists the owner configuration and verification steps. Nothing has been publicly deployed.
