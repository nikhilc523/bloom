# Bloom — Product Brief

*Synthesis of the five research briefs into product decisions. Working title: **Bloom.***

---

## 1. What we're building & why it can win

A period-tracking app for one woman, designed so her partner can genuinely *show up for her* — without the app ever becoming a surveillance tool or a weapon. The market research is unambiguous about where the white space is:

> The sharpest, least-served axis is **partner intimacy done respectfully** — bidirectional, consent-gated, privacy-preserving, warmly (not creepily) AI-assisted, on an honest free tier. Cycles proved couples want this; no one has built it without turning the partner into a spectator, the user into a surveillance subject, or the data into a product.

Every incumbent forces a trade-off we refuse to make:

| Incumbent weakness | Bloom's answer |
|---|---|
| Partner features are one-way, view-only, or all-or-nothing (Cycles, Glow, Clue) | **Bidirectional + per-item consent** — she shares *interpretations*, not her diary |
| Cycles charges *both* partners | **Free core forever; partner side always free** |
| Flo/Stardust/Glow burned users on privacy | **Privacy as architecture** — on-device math, E2E via CloudKit, no data-as-ad-signal, ever |
| Notification abuse (Eve) or under-prompting (Apple) | **Sparse, phase-aware, warm nudges** (≤3–4/cycle, quiet hours) |
| Creepy or shallow AI | **Warm, boundaried companion** that keeps intimate data off third-party models where possible |
| Flo dropped Apple Health sync; Cycles/Spot On have no cloud backup | **Two-way HealthKit + iCloud sync from day one** |

## 2. Positioning in one line

> **A calm, pink-glass cycle tracker with a warm AI companion — and a partner who finally knows how to be there for you, only ever seeing what you choose to show.**

## 3. Design principles (the non-negotiables)

1. **She is the data controller. He is a guest.** The relationship is *not* the security model. → [research/03](../research/03-partner-sharing-privacy.md)
2. **Share interpretations, not the diary.** The partner gets "be extra gentle today," never "cramps 4/5 + rage."
3. **Hiding is invisible and unpunished.** Un-shared and un-logged look *identical* on his side. Revoke is one silent tap.
4. **Charm on the surface, restraint underneath.** Serene minimal home; rich data at depth-2; playful 3D-emoji as reward, never noise. → [research/05](../research/05-ai-and-design.md)
5. **The AI is honest about being AI.** Always-visible disclaimer, hard red-flag escalation, never diagnoses. → [research/05](../research/05-ai-and-design.md) §A1
6. **Never claim contraception.** We predict for *awareness*; only Natural Cycles is FDA-cleared. → [research/01](../research/01-clinical-science.md) §4

## 4. Feature set — Core-minimal vs Advanced

Everything maps to the clinical brief ([research/01](../research/01-clinical-science.md) §2). The **home surface shows only core-minimal**; advanced fields live behind a toggle or a life-stage mode.

### Core-minimal (default, low-friction daily log)
- Period start/end + **flow** (spotting/light/medium/heavy)
- **Cramp/pain** severity
- **Mood** (multi-select) + **Energy** (low/normal/high)
- **PMS symptoms** checkbox set (bloating, breast tenderness, headache, cravings)
- **Sex / protection** (private, un-shareable)
- The **Cycle Ring** (current day + phase), **Mood Weather** tile, one **Floating Pinned Note**

### Advanced (toggle / mode-gated)
- Blood color & clots, pain location, BBT, cervical mucus, cervical position, LH/OPK, medication/birth control, discharge, digestion/bloating, headaches/migraines, cravings, skin, sleep, weight, water, libido
- **Insights & charts** (pattern detection, cycle history)
- **Doctor-visit export** (talking points + 12-mo PDF)
- **Clinical flags** engine ("this may be worth discussing with a clinician") → [research/01](../research/01-clinical-science.md) §3

### Life-stage modes (change fields, flags, prediction) → [research/01](../research/01-clinical-science.md) §5
Cycle (default) · TTC · Pregnancy · Postpartum · Perimenopause · Birth-control/suppression · Teen. Each reshapes normal-range bounds and what's surfaced.

## 5. The partner experience (the differentiator)

Full model in [research/03](../research/03-partner-sharing-privacy.md). The essentials:

- **Three sharing presets** she can fully override: **Minimal** (phase + "period started") · **Supportive** (default — adds gentle-window + next-period *window*) · **TTC** (adds fertile window, only if both in TTC mode).
- **A live "What [name] sees" mirror** — she never guesses.
- **Un-shareable categories have no toggle:** sexual activity, contraception, weight, Private-tagged notes — so they can't be pressured out of her.
- **Partner side = care cues, not a dashboard:** "This week, in a sentence," gentle heads-up, concrete opt-in gestures, a soft countdown. Subject of every sentence is *him and his gesture*, never *her deficiency*.
- **Floating pinned notes** (the heart): 💛 love note · ⏰ reminder · ✨ highlight (her voice). Home-screen widget is the hero surface. Mute/dismiss silently, no read receipts.
- **Safety:** one-tap silent revoke, breakup purges his cache, a Quiet/Safety exit that hides the partner feature entirely.

## 6. AI features (warm, boundaried) → [research/05](../research/05-ai-and-design.md) Part A

- **Ask Bloom** — warm health chat (Sonnet 4.6), grounded in her data, with a hard red-flag escalation list reviewed by a clinician.
- **Phase insights** — calm cards (Haiku 4.5 over a clinician-reviewed template floor).
- **Pattern detection** — stats computed *on-device*; AI only phrases the finding; exports as doctor talking points.
- **Predictive heads-up** — own model predicts; AI narrates *with the uncertainty band*.
- **Partner AI** — "For [name], this week" (Haiku), opt-in, abstracted, same guardrails.
- **Notification intelligence** — precomputed nightly, sparse, phase-aware, quiet-hours-respecting, discreet on the lock screen.

## 7. MVP scope (what ships first)

**In:** solo cycle tracking (core-minimal log + Cycle Ring + calendar), prediction with uncertainty bands, two-way HealthKit sync, iCloud cross-device sync, the pink-glass design system, phase insight cards, sparse local notifications, and the **partner link + Supportive-preset sharing + one floating pinned note each way**.

**Deferred to v1.1+:** Ask Bloom chat, pattern detection & charts, full life-stage modes beyond Cycle/TTC, doctor-export PDF, wearable temp integrations, Live Activity.

**Explicitly out (for now):** community/forums, contraception-efficacy claims, Android.

Rationale: the partner-sharing + privacy architecture is the moat and the riskiest to retrofit, so it's in the MVP even though the AI chat (easier to add later) is not. → build sequence in [02-build-plan.md](02-build-plan.md).
