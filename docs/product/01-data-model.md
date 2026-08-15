# Bloom — Data Model / Tracker Spec

*Derived from the clinical brief ([research/01](../research/01-clinical-science.md)) and the partner-sharing rules ([research/03](../research/03-partner-sharing-privacy.md)). Types are described conceptually; the iOS mapping is SwiftData models + a separate CloudKit shared zone ([research/04](../research/04-apple-tech.md)).*

---

## Core principle

Store **enumerated categorical scales**, not free text, so everything is chartable and flag-able. Predictions are stored as **ranges + confidence**, never single dates.

## Entities

### `User`
`id · displayName · birthDate(opt) · lifeStageMode · avgCycleLength · avgPeriodLength · onboardedAt · sharingPreset`

`lifeStageMode ∈ { cycle, ttc, pregnancy, postpartum, perimenopause, birthControl, teen }` — controls active fields, flag thresholds, prediction validity.

### `Cycle` (derived + editable)
`id · startDate · endDate(opt) · lengthDays · periodLengthDays · ovulationEstimate{date, confidence} · fertileWindow{start, end, confidence} · isPredicted`
- Never render a single ovulation date without its confidence. Predicted days show as **ghost/dashed** in UI.

### `DailyLog` (one per day; all fields optional)
The backbone. Grouped by tier + shareability.

| Field | Type | Tier | Shareable? |
|---|---|---|---|
| `flow` | enum: none/spotting/light/medium/heavy | core | as state only ("period started") |
| `crampSeverity` | 0–10 | core | no (→ derived cue) |
| `mood` | multi-enum: calm/happy/irritable/anxious/low/sensitive | core | **opt-in, softened** |
| `energy` | enum: low/normal/high | core | **opt-in, softened** |
| `pms` | multi-enum: bloating/breastTenderness/headache/cravings | core | no |
| `sexActivity` | enum: none/protected/unprotected | core | **NEVER (un-shareable)** |
| `bloodColor` | enum: bright/dark/brown | adv | no |
| `clotSize` | enum: none/small/large(≥2.5cm) | adv | no (feeds flag) |
| `painLocation` | multi-enum: pelvic/lowBack/legRadiating/oneSided | adv | no |
| `bbt` | decimal °C/°F | adv | no |
| `cervicalMucus` | ordered enum: dry/sticky/creamy/eggwhite | adv | no |
| `cervicalPosition` | ordered enum (SHOW: soft/high/open/wet) | adv | no |
| `lhTest` | enum: negative/positive | adv | no |
| `medication` | list{name, type, taken:bool, time} | adv | **NEVER (un-shareable)** |
| `discharge` | enum + flags (odor/itch) | adv | no |
| `digestion`, `headache`, `cravings`, `skin`, `sleepQuality` | enums | adv | no |
| `weight` | decimal | adv | **NEVER (un-shareable)** |
| `waterIntake`, `libido` | numeric/enum | adv | no |
| `note` | free text, `isPrivate:bool` | adv | **per-note opt-in; Private = un-shareable & invisible** |

### `Prediction`
`nextPeriod{windowStart, windowEnd, confidence} · nextOvulation{...} · basis: enum(calendar/bbt/symptothermal) · generatedAt`
- Computed **on-device** ([research/05](../research/05-ai-and-design.md) privacy posture). Confidence degrades with sparse logging / irregularity / PCOS / perimenopause.

### `ClinicalFlag` → [research/01](../research/01-clinical-science.md) §3
`id · type · triggeredByRule · severity · message · createdAt · dismissed`
- Types: heavyBleeding, irregularCycle, shortLongCycle, missedPeriod, possiblePCOS, possibleEndometriosis, possibleThyroid, pregnancySignal, urgent.
- **Every message ends in "…may be worth discussing with a clinician."** Never a diagnosis.

### Rule thresholds (the flag engine)
- Heavy bleeding: flow=heavy ≥ consecutive hours, or period > 7 days, or clot ≥ 2.5cm
- Irregular: cycle length shifting ≥ 7–9 days
- Short/long: < 21 or > 35 days (adults; teen mode widens to 45)
- Missed: no period ≥ 90 days (→ pregnancy-test prompt first)
- Urgent: bleeding with dizziness/SOB, inter-menstrual/post-coital, post-menopausal

---

## Partner-sharing model (separate store)

### `PartnerLink`
`id · partnerName · linkedAt · sharingPreset(minimal/supportive/ttc) · fieldOverrides:map<field,bool> · status(active/revoked)`

### `SharedState` (the ONLY thing that crosses to the partner — interpretations, not logs)
`currentPhaseLabel · periodStartedFlag · nextPeriodWindow · gentleWindowActive:bool · moodWeather(opt, she-confirmed) · fertileWindow(TTC only)`
- Lives in a **CloudKit shared zone** ([research/04](../research/04-apple-tech.md)). Short TTL cache on his device; server-authoritative access check on every fetch; **no historical archive on his side**.
- On revoke/breakup: blank his view + purge his cache. Hidden ≡ un-logged (indistinguishable).

### `PinnedNote`
`id · authorId · type(love/reminder/highlight) · text(capped) · createdAt · deliveredAt · mutedByRecipient:bool`
- One active pin per person (small stack ≤3). No edit-after-delivery. No read receipts. Reactions = a heart tap.

---

## Storage split (critical architecture decision → [research/04](../research/04-apple-tech.md))

| Data | Store | Why |
|---|---|---|
| Her private cycle data (User, Cycle, DailyLog, Prediction, Flag) | **SwiftData + CloudKit private DB** | Lowest-effort cross-device sync; stays isolated |
| Reproductive-health samples | mirrored to **HealthKit** (two-way) | Syncs with Apple's built-in Cycle Tracking |
| Partner shared layer (SharedState, PinnedNote) | **CloudKit custom zone + CKShare** (direct, not SwiftData) | SwiftData can't use shared/public DB; only the explicitly shared zone crosses accounts |

**Keep the two stores separate** so partner-sharing complexity stays isolated from her private data.
