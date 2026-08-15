# Partner Sharing for a Period Tracker — Design & Privacy Brief

*Opinionated by design. The organizing principle: **she is the data controller, he is a guest in her app, and the relationship is not the security model.***

---

## 0. The one belief that shapes everything

Most "couple" period features get built from the *partner's* curiosity ("I want to know when to expect PMS"). That framing is where they go wrong. The people who log their cycle are overwhelmingly making themselves legible to someone with more social power in the average heterosexual relationship. Researchers warn these wellness tools can be "weaponized for legal and commercial interests" and enable **intimate harms** and coercive control ([ScienceDirect: *Intimate harms and menstrual cycle tracking apps*](https://www.sciencedirect.com/science/article/pii/S0267364924001043); [Cambridge](https://www.cam.ac.uk/research/news/menstrual-tracking-app-data-is-a-gold-mine-for-advertisers-that-risks-womens-safety-report)).

So the differentiator isn't "sharing." Every competitor shares. The differentiator is that **she chooses the frame**, defaults protect her by revealing little, and *hiding is never punished*. Build for the woman who loves and trusts her partner **and** for the woman who is quietly starting to be afraid of him — the same UI has to serve both, because she often can't tell the app which one she is.

---

## 1. The Sharing Permission Model

### Design stance
Competitors ship a **binary + opaque** model: Cycles shares "cycle info" but keeps reminders/notes private; Flo shares "period and fertile window" predictions once you hand over a code; Natural Cycles' Partner View shares *fertility status*. None let her see, per-item, *exactly what he sees*, and none default to the most protective view.

We do three things differently: **(a) share interpretations, not raw logs; (b) protective defaults; (c) a live "What he sees" mirror.**

### Share *derived meaning*, not the diary
The partner should almost never receive a raw data point. He receives a **translation**: "Be extra gentle today," not "she logged cramps 4/5 + rage." This is the single most important privacy and dignity decision in the product. Raw symptom logs are how a mood tracker gets weaponized (§2). Translations are supportive and low-resolution by design.

### Default matrix

| Item | Default | Rationale |
|---|---|---|
| Current phase, plain-language | **Shared** | Low-sensitivity, high-support-value framing |
| "Period likely started" (state, not flow/heaviness) | **Shared** | The single most useful cue for a caring partner |
| Predicted next period (a *window*, e.g. "~in 4–6 days", never a hard date) | **Shared** | Windows resist "you're late" surveillance |
| PMS / luteal heads-up ("gentle window this week") | **Shared** | The care payload — but softened (§2) |
| Mood/energy "weather" (one emoji + one word, she confirms before it sends) | **Off by default, easy opt-in** | Mood is the most weaponizable field. Never auto-broadcast raw mood. |
| "Be extra gentle today" / "low-spoons day" cue | **Shared, but she taps to send it** | Consent per instance |
| TTC fertile window | **Shared *only in TTC mode*, and only if both are in TTC mode** | Coordination when trying; pressure/surveillance when not |
| Specific symptoms (cramps, headache, nausea, acne, discharge, libido) | **Hidden** | She can promote individual ones if she wants |
| Sexual activity / intercourse logs | **Hidden, and *un-shareable* — no toggle exists** | No supportive reason a partner needs the log. Removing the toggle removes the coercion vector. |
| Contraception use | **Hidden, un-shareable** | Coercion + legal-risk surface |
| Weight, BMI, body measurements | **Hidden** | No care value; high shame/control value |
| Free-text notes / journal | **Hidden**; per-note "share this" only | The diary. Opt-in per note, never per app. |
| Anything tagged **Private** | **Hidden, un-shareable, invisible that it exists** | See §4 |

### The rules that make the matrix trustworthy
1. **Levels, not a switch.** Onboarding offers three presets she can fully override: **Minimal** (phase + "period started" only) · **Supportive** (adds gentle-window + next-period window) · **TTC** (adds fertile window). Default to **Supportive**, but list Minimal first so the protective option isn't buried.
2. **Full item-level override.** Every row is individually toggleable.
3. **A live "What [name] sees" mirror.** A dedicated screen renders the *exact* partner view. No sharing feature ships without it. This is the trust anchor.
4. **Un-shareable categories genuinely have no toggle** — so a partner can never pressure her to flip a switch that doesn't exist.

---

## 2. Partner-Side Experience — warm, useful, un-weaponizable

Framed as **"What's she going through, and what helps?"** — never a dashboard of her body.

- **This week, in a sentence:** "She's in her luteal phase — she may have less energy and be more sensitive. A little extra patience goes a long way." (Interpretation, not symptoms.)
- **A gentle heads-up, not an alarm:** "Her period may start in the next few days." Soft window language.
- **Concrete, opt-in gestures:** a rotating card — "Some people appreciate: a heat pad, their favorite snack, an early night, or just being asked how they're doing." Always hedged so it never becomes "the app said you want chocolate."
- **A soft countdown** to the next expected period *window* — present but never front-and-center.
- **Education, done well:** informed partners are kinder partners — keep it about empathy, not "managing" her.

### Avoiding the "mood tracker weaponized" failure mode
The catastrophic outcome is **"you're just being emotional / you're PMSing"** — the app handing him a rhetorical weapon. Guardrails:

1. **Never show raw mood or symptom data to the partner** — only softened cues she sends or opted into.
2. **Cues describe *his* recommended behavior, not *her* deficiency.** "A good day to be extra patient" ✅. "She is irritable" ❌.
3. **No accuracy scoreboard.** Never surface "prediction vs. actual."
4. **No historical mood/symptom timeline on the partner side.** He sees *now and near-future support*, never a browsable archive.
5. **She can mute the interpretation any day** without him being told.
6. **Reciprocity by design.** A two-way channel, not him observing a specimen.

---

## 3. The Floating Pinned Notes / Messages Feature

This is the feature people will *love* — the humane counterweight to data-sharing. Precedent: "Love Notes" widgets and Cupla's home-screen widgets + shared reminders.

### Model
- **Pinned notes** = small, persistent, affectionate/supportive messages that *float* on the other person's home screen (widget) and app home. Not a chat log — a **fridge magnet**, not a DM thread. Persistence is the feature.
- **Three note types**, visually distinct:
  - 💛 **Love note** — "thinking of you." Ambient.
  - ⏰ **Reminder** — "take your iron," "heat pad's charged" — gentle, opt-out-able.
  - ✨ **Highlight** — *she* pushes something to him: "heads up, rough day" or "I'd love flowers this week." Her voice, her framing.
- **He can pin a note *to her cycle context*:** when she enters her gentle window, a pre-written "whatever you need this week, I've got you" surfaces at the right time — he's preparing to serve, not to observe.

### UX patterns
- **One active pin per person** (or a tiny stack of ~3). Scarcity keeps each note meaningful.
- **Reactions, not obligation.** A heart/tap acknowledges. **No read receipts.**
- **Tone-safe composing.** Length caps; a gentle nudge if a note reads harshly.
- **She can dismiss or mute any incoming pin**, silently.
- **No editing after delivery / clear timestamps** — small anti-gaslighting affordance.
- **Home-screen widget is the hero surface.**

---

## 4. Consent & Safety — the part most competitors under-build

The threat model is real and documented: period-app data enables "health insurance discrimination… or even domestic abuse," and post-*Dobbs* it's a legal-exposure surface; the FTC already charged Flo for secretly sharing intimate data ([Forbes / post-Roe](https://www.forbes.com/sites/abigaildubiniecki/2024/11/14/post-roe-your-period-app-data-could-be-used-against-you/); [California Law Review](https://www.californialawreview.org/print/leak-the-legal-consequences-of-data-misuse-in-menstruation-tracking-apps)).

### Non-negotiable safety requirements

1. **Revoke instantly, from anywhere, one tap, no friction.** Revocation immediately blanks his view and triggers deletion of his cached copy.

2. **THE CARDINAL RULE — no notification on hide or revoke.** Hiding an item, muting a day, or ending sharing must **never** notify or be visible to the partner. His view degrades **gracefully and ambiguously**: a hidden item looks identical to a day with nothing logged. **Un-shared and un-logged must be indistinguishable.** This one rule is the difference between a safety feature and a trap.

3. **Hidden data is invisible-that-it-exists.** No "1 item hidden" badge, no locked rows, no greyed-out placeholders on his side.

4. **Breakup / disconnect flow:**
   - Either person can disconnect; **her disconnect is silent and immediate**.
   - On disconnect, **his device purges all cached cycle data and pins**; server-side sharing state is deleted.
   - Offer her a **"clean break"**: wipe shared history and pins from both sides. Her own data is untouched — only the shared layer dies.
   - **No re-link without a fresh invite from her.**

5. **Coercion-aware design.**
   - A **Quiet/Safety exit**: revoke + disconnect + hide the partner feature entirely from her app in one silent action.
   - **No partner-side location, no "last active," no login/activity signals.**
   - Frame all sharing prompts as **her choosing to give**, never "unlock more for your partner."
   - Never let the partner *request* a specific hidden field.

6. **Data minimization on the partner side.** The partner app holds the **minimum derived state** to render care cues — ideally *interpretations only* ("gentle window active"), not her underlying logs. Short TTLs on his cache, server-authoritative access checks on every fetch, no local archive he can keep after revocation.

---

## 5. Competitor scan — copy vs avoid

| App | What it does | **Copy** | **Avoid** |
|---|---|---|---|
| **Cycles** | Shares cycle info; reminders/notes private | Notes-private-by-default; "support without having to ask" | Coarse/opaque sharing; defaults lean revealing |
| **Flo for Partners** | Share a code; partner sees period + fertile window, education/quizzes | Excellent partner *education*; "stop sharing anytime" | Fertile window shared outside TTC = surveillance; FTC-charged for secret data sharing |
| **Natural Cycles Partner View** | Shares *fertility status* | Sharing an *interpreted state*, not raw temps | Fertility-forward framing centers conception/sex, not everyday care |
| **Cupla** | Shared calendar, reminders, home-screen widgets | Widget-first ambient presence; shared reminders | "Share everything" defaults unfit for health data |
| **Love Notes widget** | Sweet notes on partner's home screen | The floating-pin delight (§3) | No consent/mute model — we must add dismiss/mute/no-read-receipts |
| **Paired / Lasting** | Connection, prompts | Warm, reciprocal, *shared* rather than *observed* tone | Relationship "scores"/monitoring framings |
| **MoodMe** | Partners track each other's moods | — | The cautionary tale: broadcasting raw mood is the weaponization vector |

---

## TL;DR — the five commitments

1. **Share interpretations, not the diary.** He gets "be gentle today," never her symptom log.
2. **Protective defaults + total override + a live "what he sees" mirror.** She's never guessing.
3. **Un-shareable means the toggle doesn't exist** (sex, contraception, weight, Private) — so it can't be pressured out of her.
4. **Hiding is invisible and unpunished** — un-shared and un-logged look identical; revoke is one silent tap; breakup purges his cache.
5. **The pinned-notes feature is the heart** — warmth and reciprocity, with mute/dismiss and no read receipts.
