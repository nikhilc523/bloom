# Bloom 🌸

A period-tracking iOS app built for one person, whose differentiator is **respectful partner sharing**: she tracks her cycle; her partner sees only what she chooses (interpretations, never her diary) and can send warm floating pinned notes. Pink-glossy, minimal UI. Warm, boundaried AI. Privacy as architecture.

> Full product thesis, research, and specs in [`docs/`](docs/README.md).

## Status

Early scaffold. A minimal buildable app (Cycle Ring + a period-log flow) with unit + UI tests and CI. See [`docs/product/02-build-plan.md`](docs/product/02-build-plan.md) for the roadmap.

## Getting started

Requires **Xcode 26+** and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). The `.xcodeproj` is generated, not committed.

```bash
xcodegen generate            # create Bloom.xcodeproj from project.yml
open Bloom.xcodeproj         # then run in Xcode

# or build + test from the CLI:
xcodebuild test -project Bloom.xcodeproj -scheme Bloom \
  -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

## Project layout

| Path | What |
|---|---|
| `Bloom/` | App sources (SwiftUI, pink-glass design system, models) |
| `BloomTests/` | Unit tests (Swift Testing) |
| `BloomUITests/` | UI tests (XCUITest) |
| `project.yml` | XcodeGen spec — source of truth for the project |
| `docs/` | Research dossier + product brief, data model, build plan |
| `.claude/skills/` | 11 AI delivery skills (dev, test, bug-find, UI automation, release gate) |
| `.github/workflows/` | CI (build + test + coverage) |

## AI-assisted development

This repo is set up for [Claude Code](https://claude.com/claude-code):
- **11 project skills** in `.claude/skills/` — see [`.claude/skills/README.md`](.claude/skills/README.md).
- **Live UI validation** via `.mcp.json` (XcodeBuildMCP + ios-simulator-mcp). Run `brew install idb-companion` and approve the servers on first launch.
- **Claude PR review** is not wired up yet — add it later, see [`docs/SETUP-github-claude.md`](docs/SETUP-github-claude.md).

## Privacy & safety

The partner-sharing model is consent-first and covers the abuse/coercion failure modes most apps ignore. The non-negotiable invariants are documented in [`docs/research/03-partner-sharing-privacy.md`](docs/research/03-partner-sharing-privacy.md) and gated by the `ios-release-validator` skill. Not a medical device; makes no contraception claims.
