# Bloom — Research & Product Dossier

A period-tracking app built *for one person*, whose differentiator is **respectful partner sharing**: she tracks her cycle; her partner sees only what she chooses (interpretations, never her diary) and can send warm floating pinned notes. Pink-glossy, 3D-emoji, minimal UI. Warm, boundaried AI. Privacy as architecture.

*Compiled 2026-08-15 from five parallel research agents. All research is cited inline.*

## Research (raw findings, cited)
1. [Clinical science](research/01-clinical-science.md) — cycle phases, hormones, full list of what to track (core vs advanced), clinical red-flags & thresholds, prediction methods & limits, life-stage modes.
2. [Competitor teardown](research/02-competitor-teardown.md) — Flo, Clue, Stardust, Natural Cycles, Apple, Ovia, Glow, Cycles, Spot On, Oura, Whoop + feature matrix, post-Roe privacy landscape, partner features, and **the gaps we can own**.
3. [Partner sharing & privacy](research/03-partner-sharing-privacy.md) — the consent-first sharing model, the default matrix, partner-side experience, floating pinned notes, safety/breakup/coercion handling.
4. [Apple ecosystem tech](research/04-apple-tech.md) — HealthKit two-way sync, CloudKit/CKShare for the partner layer, notifications, widgets, stack recommendation.
5. [AI features & design](research/05-ai-and-design.md) — the warm AI companion + responsible guardrails + model routing, and the concrete pink-glass 3D SwiftUI visual language.

## Product (decisions & specs)
- [Product brief](product/00-product-brief.md) — vision, positioning, principles, feature set (core-minimal vs advanced), partner experience, AI, **MVP scope**.
- [Data model / tracker](product/01-data-model.md) — entities, per-field tier + shareability, flag-engine thresholds, the two-store architecture.
- [Build plan](product/02-build-plan.md) — tech stack, compliance gates, roadmap (phases 0–4), **recommended MCP servers & AI tooling**, next steps.

## The one-sentence thesis
> Every incumbent forces a choice between good privacy *or* good partner features. Bloom refuses the trade-off: bidirectional, consent-gated, privacy-preserving partner sharing on an honest free tier — the thing Cycles proved couples want but no one has built without turning the partner into a spectator or the user into a surveillance subject.
