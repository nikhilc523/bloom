# Bloom — project instructions

Bloom is a privacy-first iOS period tracker (SwiftUI + SwiftData + CloudKit + HealthKit). Product thesis, research, and specs live in [`docs/`](docs/README.md). AI delivery skills live in [`.claude/skills/`](.claude/skills/README.md).

## 🚨 MANDATORY: before ANY `git push` or pull request

**You MUST load and follow the [`github-push`](.claude/skills/github-push/SKILL.md) skill before every push.** This is non-negotiable. Whenever you are about to run `git push`, open a PR, or the user asks you to push/ship/PR:

1. Invoke the `github-push` skill (via the Skill tool) and follow its checklist in order.
2. Never push directly to `main` — it is branch-protected. Branch → local tests green → PR → **green CI** → merge.
3. Never merge a PR until the **Build & Test** check is green. Do not use admin bypass unless the user explicitly tells you to.

If a push would violate the `github-push` gate (secrets staged, tests failing, privacy leak, on `main`), STOP and fix it first — do not push.

## Working conventions
- Feature work follows the `swiftui-developer` skill and the architecture guardrails in `docs/product/`.
- New behavior ships with a test (`test-requirements` → `swift-unit-tests` / `snapshot-testing` / `xcuitest-writer`).
- Privacy invariants in `docs/research/03-partner-sharing-privacy.md` are hard constraints, gated by `ios-release-validator`.
- The `.xcodeproj` is generated from `project.yml` (XcodeGen), not committed.
