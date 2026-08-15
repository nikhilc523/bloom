# AI Features & Pink-Glossy-3D Design Language

*Working title used throughout: **"Bloom."** Two parts: (A) genuinely useful, non-creepy AI, and (B) a concrete pink-glossy 3D visual language buildable in SwiftUI today.*

---

## PART A — Useful, Non-Creepy AI Features

Design principle: **the AI earns trust by being warm, boundaried, and legible.** It explains *why* it's saying something ("based on your last 3 cycles…"), never diagnoses, and hands off to a human the moment a red flag appears. This is product survival, not just ethics — a recent study found most AI health chatbots have *dropped* medical disclaimers, and regulators are moving to treat health chatbots as medical devices ([Petrie-Flom / Harvard Law](https://petrieflom.law.harvard.edu/2026/05/26/health-ai-chatbots-are-legally-medical-devices-its-time-the-fda-started-treating-them-like-it/), [Computerworld](https://www.computerworld.com/article/4026778/ai-chatbots-ditch-medical-disclaimers-putting-users-at-risk-study-warns.html)).

### A1. The Companion — "Ask Bloom" (warm health chat)

A conversational surface answering period/cycle/body questions in plain, kind language — a companion who remembers your context.

**Behaviors:** answers "is it normal that…" with reassurance *plus* a boundary; grounds answers in the user's own tracked data ("You logged cramps on days 1–2 the last three cycles, so this fits your pattern"); warm, short sentences, never patronizing.

**Guardrails (non-negotiable):**
1. **Persistent, honest disclaimer** — a compact always-visible "Bloom is an AI companion, not a doctor" line on the chat surface.
2. **Escalate-to-doctor triggers** — a hard-coded red-flag list (soaking a pad/hour, bleeding while pregnant, severe one-sided pelvic pain, fainting, bleeding after menopause, thoughts of self-harm). On match, the model *stops advising* and surfaces a calm "please talk to a clinician / here's a hotline" card.
3. **Never gives cleared-medical advice it isn't cleared for** — no contraception dosing, no diagnosis, no drug recommendations. It explains concepts and routes decisions to a clinician.
4. **Involve real experts** — the red-flag taxonomy and refusal copy reviewed by an OB-GYN/nurse.

**Build (Claude API):** **Claude Sonnet 4.6** (`claude-sonnet-4-6`) as the default chat model (best speed/warmth/cost balance). Reserve **Claude Opus 4.8** (`claude-opus-4-8`) for hard multi-step reasoning turns ("summarize what changed across my last 6 cycles and what to raise with my doctor"). Route by turn complexity.
- Frozen safety **system prompt** with `cache_control: {type: "ephemeral"}` — cheap across turns, never drifts.
- **Adaptive thinking** (`thinking: {type: "adaptive"}`) — reasons harder on ambiguous symptom questions.
- **Stream** responses for a live-typing feel.
- Handle `stop_reason: "refusal"` gracefully — render the escalation card.

### A2. Cycle-Phase Insights (personalized, calm)
Short phase cards: *"You're in your luteal phase — cravings, lower energy, and a shorter fuse are all normal right now."* Each phase gets a distinct tone, a matching 3D-emoji mood, and 1–2 concrete tips. **Build:** cheap classification + templated generation with **Claude Haiku 4.5** (`claude-haiku-4-5`), over a clinician-reviewed template library as the safe floor.

### A3. Symptom Pattern Detection (over time)
Quietly notices recurring signals: *"Headaches have clustered on days 26–28 in each of your last 4 cycles."* Surfaced as gentle observations and, crucially, **exportable talking points for a doctor visit** — reframing the AI as helping you advocate for yourself ([NCBI: women's preferences for AI in women's health](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12172807/)). **Build:** statistical pattern-finding **on-device / in your own code**; Haiku only phrases the finding. The model never invents patterns.

### A4. Predictive Heads-Up (with humility)
*"Your next period is likely around Aug 22 (±2 days)."* Predictions are your own cycle-length model's job; Claude narrates. **Always show the uncertainty band.**

### A5. Partner-Facing AI — "For [partner], this week"
Opt-in, user-controlled: *"She's likely in her luteal phase this week — a quiet night in and not sweating the small stuff goes a long way."* Concrete, kind, never clinical, never raw symptom data. **She controls everything** (off by default, granular, one-tap revoke); abstracted not surveillant; same medical guardrails. **Build:** Haiku 4.5 from phase + her explicitly-shared preferences.

### A6. Notification Intelligence — warm, well-timed, never creepy
The line between "thoughtful" and "creepy" is **timing, tone, and control.**
- **Anticipatory, not reactive:** "Your period's likely tomorrow — maybe pack a few things 💗" (day before, morning).
- **Phase-aware tone:** gentle in luteal/menstrual, upbeat in follicular.
- **Sparse:** hard cap (≤3–4 pushes/cycle). Insight cards live *inside* the app.
- **Quiet hours + user-set cadence** (minimal / normal / off).
- **Never leak on lock screen:** discreet copy ("Bloom has a note for you").
- **Avoid:** streak-nags, over-precise body claims as fact, surveillance vibes.

**Build:** precompute the notification *decision* with Haiku nightly (respecting quiet hours + cadence cap); schedule locally. Never send raw health data on a notification path when a template ID will do.

### Privacy posture (cross-cutting)
- **Minimize what leaves the device.** Predictions, pattern-detection, notification decisions run on-device. Claude sees only de-identified context (phase, symptom *categories*, cycle-day) — never name/email/geolocation.
- **On-device vs API:** on-device for math/stats/gating; Claude API for language. For chat, the API is worth it — but send the leanest, least-identifiable context.
- **No health data as ad signal, ever.** Trust is the entire moat.

**Model summary:** Opus 4.8 = hard reasoning turns only · **Sonnet 4.6 = chat companion (default)** · **Haiku 4.5 = classification, phase insights, pattern phrasing, partner guidance, notification decisions.**

---

## PART B — Visual Design Language (Pink Glossy, 3D, Minimal)

### B1. The aesthetic, grounded
The current wave is **"Liquid Glass"** (Apple's glossy, translucent, light-bending surfaces) over **soft glassmorphism**, **fluid blob shapes**, and **ambient color orbs** floating behind the UI. For a young woman's period app: **frosted glass cards over a warm pink gradient field, with a few chunky 3D-emoji characters as the emotional anchor.** Caution: glassmorphism wrecks contrast — glass is for *chrome and cards*, never body-text backgrounds ([Medium — the beautiful trap](https://medium.com/design-bootcamp/glassmorphism-the-most-beautiful-trap-in-modern-ui-design-a472818a7c0a)).

### B2. Concrete palette

| Role | Hex | Use |
|---|---|---|
| Blush (bg base) | `#FFF0F4` | App background, top of gradient |
| Petal | `#FBD5E3` | Gradient mid, card tints |
| Rose (primary) | `#F48FB6` | Primary accent, ring fill start |
| Deep Rose | `#D9538B` | CTA, ring fill end, active states |
| Plum ink | `#3A2431` | Primary text (warm near-black, not `#000`) |
| Mist | `#8A7480` | Secondary text / captions |
| Accent — Periwinkle | `#8AA0F0` | The one non-pink: info, "insight" chips, links |
| Glass white | `#FFFFFF @ 55–70%` | Frosted card fill |

**Ambient orbs** behind the glass: 2–3 soft radial blobs (Rose / Periwinkle / warm peach), heavily blurred, drifting slowly.

### B3. Typography
- **Display / numbers:** rounded warm serif or soft-geometric sans with personality (**Fraunces**, or **SF Rounded** for native feel). Big cycle-day numbers deserve character.
- **Body / UI:** **SF Pro** (or Inter). Never set body text on glass.
- Scale: hero number ~64–80pt, section titles ~22–28pt, body 15–17pt. Minimal = few sizes, lots of air.

### B4. Corner-radius & soft-shadow system
- **Radius tokens:** `sm 12` · `md 20` · `lg 28` · `pill 999`. **Always `.continuous`** corners.
- **Soft-shadow token (puffy 3D feel):** `color: DeepRose @ 12–18%, radius: 24, y: 12`. Optional faint inner top highlight for the glossy dome.
- **3D edge trick:** a `stroke` with a `LinearGradient` (white-ish top-left → transparent bottom-right) gives the beveled lit-glass edge.

### B5. Component list
1. **Cycle Ring** (hero) — circular progress ring (cycle day / phase), `LinearGradient` Rose→DeepRose fill, gradient stroke for the lit edge, big cycle-day number centered, a 3D-emoji mood floating at the leading point.
2. **Phase Cards** — frosted glass, tinted per phase, with the phase's 3D emoji.
3. **Mood Weather** — a "today's mood forecast" tile: a 3D-emoji face (sunny/cloudy/stormy) mapped to phase + symptoms. The signature charm moment.
4. **Floating Pinned Note** — a glass card hovering above the home surface for the single most relevant thing today. `.interactive()` glass so it bounces on tap.
5. **Calendar** — minimal month grid; period days as soft Rose dots, predicted days as dashed/ghost dots (uncertainty made visual).
6. **Ask-Bloom entry** — a pill button with glass tint and a gentle pulse.

### B6. SwiftUI implementation
**On iOS 26+ (native Liquid Glass):** use **`.glassEffect()`** (`.regular`/`.clear`), chain **`.tint(...)`** sparingly for semantic color, **`.interactive()`** for scale/bounce/shimmer-on-tap. Wrap clustered glass (ring + note + mood tile) in a **`GlassEffectContainer`** so they blend and stay performant. Native glass adds GPU lensing + gyroscope-driven reflections — lean into it for the ring and hero card.

**Backward-compatible manual glass:** a **moving glowing blob** + **`.ultraThinMaterial`** + a **subtle semi-transparent gradient border**. Ship a `GlassCard` view + `GlassPanel` modifier that **auto-upgrades to `.glassEffect()` on iOS 26** and falls back to `.ultraThinMaterial` below.

**Motion:** `.spring(response: 0.4, dampingFraction: 0.7)` for card expand/collapse and mood-tile pop. Ambient orbs drift on slow looping `.easeInOut`. Soft and springy, never snappy-linear.

**3D emoji — Rive over Lottie.** Rive's **state machine** lets one emoji react to state (phase, tap, mood) instead of fixed clips; idle CPU ≈ 0%, files 3–5× smaller, stays flat under many simultaneous animations — all of which matters with several emoji on one home screen ([Rive vs Lottie](https://unicornicons.com/learn/rive-vs-lottie)). First-class SwiftUI runtime. Use **SF Symbols** (with `.symbolEffect`) for functional icons; reserve custom 3D-emoji for emotional moments.

**Haptics:** `.impact(.soft)` on card taps, `.impact(.light)` when the ring advances a day, `.success` when a period is logged. Glass that bounces *and* buzzes softly sells "alive."

### B7. Reconciling "minimal" with "rich detail" — progressive disclosure
The home surface is **calm and near-empty on purpose:** Cycle Ring, one Mood Weather tile, one Floating Pinned Note. Rules:
1. **Home shows one number and one feeling** (cycle day + today's mood). Nothing competes with the ring.
2. **Tap-to-expand, not scroll-to-find.** Each glass card expands in place (spring) into its detail.
3. **Data lives at depth 2, never depth 0.** Charts, pattern-detection, history reached by intent.
4. **Insights are opt-in glances, not walls.**
5. **One accent = one meaning.** Periwinkle = insight/info; DeepRose = your action.
6. **Glass is chrome, never text background.**

### B8. Reference aesthetics
- **Apple's Liquid Glass** (iOS 26 system apps) — study how sparingly Apple tints.
- **Dribbble — "Period Tracker" tag & "Bloom – Women's Health & Cycle Tracker"** — pastel, cycle-ring-forward composition cues.
- **3D-emoji character style:** chunky, glossy, single-color-family (Apple/Microsoft Fluent 3D emoji) built as Rive state machines — the differentiator vs every flat pastel competitor.

---

**North star:** a serene pink-glass home that *feels alive* (bouncy glass, soft haptics, one charming 3D emoji), backed by an AI that is warm, honest about being AI, boundaried around medicine, and stingy with your data. Charm on the surface, restraint underneath.
