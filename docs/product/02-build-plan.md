# Bloom — Build Plan, Architecture & Tooling

*Synthesis of the Apple-tech ([research/04](../research/04-apple-tech.md)) and AI/design ([research/05](../research/05-ai-and-design.md)) briefs, plus recommended MCP servers and AI tooling to actually build this.*

---

## 1. Tech stack (decided)

- **SwiftUI** + **SwiftData** + **CloudKit**, iOS 17 baseline (iOS 26 unlocks native Liquid Glass `.glassEffect()`; fall back to `.ultraThinMaterial` below).
- **HealthKit** two-way sync — writing the reproductive-health samples *is* the sync with Apple's Cycle Tracking. Samples are `HKCategoryType` (menstrualFlow, ovulationTestResult, cervicalMucusQuality, intermenstrualBleeding, sexualActivity, contraceptive, pregnancy, lactation…) except `basalBodyTemperature` (`HKQuantityType`). Live sync = `HKObserverQuery` + background delivery + `HKAnchoredObjectQuery`. Needs HealthKit + background-delivery entitlements + both `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription`. Gotcha: you can't read authorization status for *read* access.
- **Two data stores** (see [data model](01-data-model.md)): SwiftData+CloudKit private DB for her data; CloudKit-direct custom zone + **CKShare** for the partner layer (SwiftData can't use the shared DB).
- **Notifications:** local via `UNUserNotificationCenter` (`.timeSensitive` needs its own entitlement). Partner pinned-notes are **fully serverless** — `CKDatabaseSubscription` (custom zones) → silent push → fetch → local alert. No custom backend needed for MVP.
- **Widgets:** WidgetKit Lock-Screen `.accessoryCircular` for the period countdown; home-screen widget as the hero surface for pinned notes. A **Live Activity is a poor fit** for a multi-day countdown (system ~8–12h limit) — reserve for an active-flow day.
- **AI:** **Claude API** — Sonnet 4.6 (chat), Haiku 4.5 (insights/patterns/partner/notification decisions), Opus 4.8 (rare hard reasoning). On-device for all math/stats/gating; API only for language, with de-identified context.
- **3D emoji:** **Rive** (state machines, ~0% idle CPU) over Lottie. SF Symbols for functional icons.

## 2. App Store / compliance gates (design in from day one)

- App Store **5.1.3** health-data rules; mandatory privacy policy; HealthKit review requirements.
- No selling/ad-use of health data — state it loudly in-product (it's the moat).
- **No contraception-efficacy claims** without FDA clearance ([research/01](../research/01-clinical-science.md) §4).
- AI: persistent disclaimer + red-flag escalation reviewed by a clinician ([research/05](../research/05-ai-and-design.md) §A1).

## 3. Roadmap

**Phase 0 — Foundations (design system + data)**
Pink-glass SwiftUI design system (`GlassCard`, `GlassPanel` auto-upgrading to `.glassEffect()`; palette + radius/shadow tokens); SwiftData models; on-device prediction engine (calendar method first) with confidence bands.

**Phase 1 — Solo MVP**
Core-minimal daily log · Cycle Ring + Mood Weather + calendar · two-way HealthKit sync · iCloud cross-device · phase insight cards (Haiku over template floor) · sparse local notifications · Lock-Screen widget.

**Phase 2 — The partner layer (the moat)**
CKShare invite flow · SharedState (interpretations only) · the three sharing presets + item overrides + **live "What he sees" mirror** · floating pinned notes (both directions) via CloudKit subscriptions · silent revoke + breakup purge + Quiet/Safety exit.

**Phase 3 — Intelligence & depth**
Ask Bloom chat (Sonnet 4.6, streaming, cached safety prompt, refusal handling) · on-device pattern detection + charts · doctor-visit export · full life-stage modes · partner AI cues.

**Phase 4 — Ecosystem polish**
Wearable temp (Apple Watch Series 8+; optional Oura/Whoop) · richer widgets · haptics pass · accessibility/contrast audit (glass never behind body text).

## 4. Recommended MCP servers & AI tooling

These plug into Claude Code / your AI dev loop to build faster. Prioritized:

| MCP / tool | Why it helps Bloom | Priority |
|---|---|---|
| **XcodeBuildMCP** (or `xcodebuild`-wrapping MCP) | Build/run/test the iOS app, boot simulators, capture screenshots — closes the loop so the agent can *see* the pink-glass UI it's building | **High** |
| **Figma MCP** (official Dev Mode MCP) | Turn design frames into SwiftUI; pull the palette/tokens/components straight from a Figma file into code | **High** |
| **Apple Developer Docs MCP** (or a WebFetch-backed docs fetcher) | Ground HealthKit/CloudKit/WidgetKit API usage in current Apple docs instead of guessing identifiers | **High** |
| **Context7** (up-to-date library docs) | Fresh docs for Rive SwiftUI runtime, CloudKit patterns, SwiftData quirks | Medium |
| **GitHub MCP** | PRs, issues, CI for the repo | Medium |
| **Filesystem / memory MCP** | Persist product decisions & keep this dossier in the agent's working context | Medium |
| **Sentry / crash MCP** (later) | Post-launch triage | Low |

**The Anthropic side:** use the **Claude API** with the model routing above; keep the safety system prompt frozen and prompt-cached; enable adaptive thinking + streaming for chat. For dev, **Claude Code** with the MCPs above is the build harness. Anthropic also ships an **iOS/Swift-friendly** path via the standard REST API — no special SDK required; a thin `URLSession` client with SSE streaming is enough.

**A note on the connected MCPs in this session** (Gmail, Google Calendar/Drive, Notion, Obsidian): none are needed to *build* the app, but **Notion or Obsidian** is a reasonable home for this research dossier + the living product spec / backlog if you'd rather manage it there than in-repo. Say the word and I can push these docs into your Obsidian vault or a Notion database.

## 5. Immediate next steps (when you're ready to build)

1. Scaffold the Xcode project (SwiftUI app, iOS 17 target) + the design-system module.
2. Wire XcodeBuildMCP + Apple-docs MCP into Claude Code so the agent can build, run, and screenshot.
3. Stand up the SwiftData models from [01-data-model.md](01-data-model.md) and the on-device calendar-prediction engine.
4. Build the Cycle Ring + one glass phase card as the visual proof-of-concept before going wide.
