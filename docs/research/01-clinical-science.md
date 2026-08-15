# Period-Tracking App: Clinical & Scientific Design Brief

*Compiled for product/data-model design. Sources are authoritative (ACOG, Cleveland Clinic, Mayo Clinic, NHS, NIH, peer-reviewed) and linked inline. This is not medical advice.*

---

## 1. Menstrual Cycle Science

A cycle is counted **Day 1 = first day of full bleeding** to the day before the next period. "Normal" adult cycle length is **21–35 days** (ACOG/Cleveland uses 21–45 for adolescents); a period lasts **≤7 days**, avg 3–5. Cycle length varies person-to-person and month-to-month — the classic "28-day / ovulate on day 14" model is an average, not a rule. ([Cleveland Clinic](https://my.clevelandclinic.org/health/diseases/17734-menorrhagia-heavy-menstrual-bleeding), [ACOG heavy bleeding FAQ](https://www.acog.org/womens-health/faqs/heavy-menstrual-bleeding))

Four key hormones drive it: **FSH** (grows follicles), **estrogen** (thickens uterine lining, rises through follicular phase), **LH** (surges to trigger ovulation), **progesterone** (dominates luteal phase, sustains lining). ([Cleveland Clinic cervical mucus / cycle](https://my.clevelandclinic.org/health/body/21957-cervical-mucus), [Clue: the menstrual cycle](https://helloclue.com/articles/cycle-a-z/the-menstrual-cycle-more-than-just-the-period))

### The 4 phases

| Phase | Typical days | Hormones | Common effects (individual variation is large) |
|---|---|---|---|
| **Menstrual** | Days 1–5 (overlaps follicular) | Estrogen & progesterone at their **lowest**; FSH begins to rise | Cramps (prostaglandin-driven), fatigue/low energy, low mood early then lifting, headaches/migraine can spike around bleeding onset, appetite/cravings, disrupted sleep from pain |
| **Follicular** | Days ~1–13 (from Day 1 to ovulation) | FSH grows follicles → **estrogen rises** | Rising energy & mood, clearer skin, improving sleep, libido climbing toward ovulation |
| **Ovulation** | ~Day 13–15 (mid-cycle; shifts with cycle length) | **LH surge** (~24–36 h before egg release); estrogen peaks; progesterone begins rising | Peak libido, peak energy, egg-white cervical mucus, possible mid-cycle (mittelschmerz) pain/spotting, BBT rises ~0.5–1°F **after** ovulation |
| **Luteal** | ~Day 15–28 (post-ovulation to next period) | **Progesterone dominant**; if no pregnancy, both hormones fall | PMS window: mood shifts/irritability, bloating, breast tenderness, cravings, acne, lower energy, disrupted sleep, cramps returning pre-period |

([Cleveland Clinic](https://my.clevelandclinic.org/health/body/21957-cervical-mucus), [Clue](https://helloclue.com/articles/cycle-a-z/the-menstrual-cycle-more-than-just-the-period))

**Fertile window & why prediction is probabilistic.** Sperm survive up to **5 days**; the egg lives only **12–24 hours** after release. This creates a ~**6-day fertile window**: the 5 days before ovulation plus ovulation day. ([ACOG via Optum](https://now.optum.com/article/health/fertility/predict-fertile-window)) Conception probability is not flat across it — roughly **~4% five days pre-ovulation, climbing to ~25–30% in the 1–2 days before ovulation, then dropping after** ([peer-reviewed cycle-mapping study, PMC9783738](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9783738/)). ACOG frames the fertile window as roughly **Days 8–19 for cycles of 26–32 days**. Because **ovulation day itself varies** cycle-to-cycle (stress, illness, weight, PCOS, perimenopause all shift it), any prediction is a probability estimate, not a fixed calendar date — a fact the app UI must communicate. ([Natural Cycles: fertile window](https://www.naturalcycles.com/cyclematters/what-is-the-fertile-window))

---

## 2. What to Track

Group by "Core minimal" (shown up-front, low-friction daily log) vs "Advanced" (behind a toggle / enabled by TTC or symptom-tracking modes).

### Core minimal (default UI)
- **Cycle start / end** (period logging) — the backbone of all prediction
- **Flow intensity** — spotting / light / medium / heavy (drives menorrhagia flags; see §3)
- **Pain / cramp severity** — 0–10 or none/mild/moderate/severe
- **Mood** — categorical multi-select (calm, irritable, anxious, low, happy…)
- **Energy** — low / normal / high
- **PMS symptoms** — bloating, breast tenderness, headache, cravings (checkbox set)
- **Sex / protection** — protected / unprotected / none (needed for pregnancy-risk and TTC logic)

### Advanced (toggle / mode-gated)
- **Blood color & clots** — bright red / dark / brown; clot size (flag clots ≥ a **quarter/2.5 cm**, see §3) ([ACOG](https://www.acog.org/womens-health/faqs/heavy-menstrual-bleeding))
- **Pain location** — pelvic, lower back, radiating leg, mid-cycle one-sided (mittelschmerz) — relevant to endometriosis pattern detection
- **Basal Body Temperature (BBT)** — first-thing-AM temp; **sustained ~0.5–1°F rise confirms ovulation retrospectively** ([Cleveland Clinic](https://my.clevelandclinic.org/health/body/21957-cervical-mucus))
- **Cervical mucus** — dry → sticky → creamy → **egg-white/stretchy (peak fertility)** ([Cleveland Clinic cervical mucus](https://my.clevelandclinic.org/health/body/21957-cervical-mucus))
- **Cervical position** — the **SHOW** signs at peak fertility: **S**oft, **H**igh, **O**pen, **W**et ([tracking guides](https://premom.com/cervix-during-ovulation/))
- **LH / OPK test result** — negative / positive surge (**+24–36 h before ovulation**)
- **Medication / birth control** — pill (with adherence), IUD, patch, ring, injection, HRT
- **Discharge** (non-fertile-mucus: color/odor/itch → infection flags)
- **Digestion / bloating**, **headaches / migraines** (menstrual-migraine pattern), **cravings**, **skin** (acne/breakouts), **sleep quality**, **weight**, **water intake**, **libido**

**Data-model note:** most fields are best stored as **enumerated categorical scales** (not free text) so they're chartable and flag-able. BBT and weight are continuous numerics; LH/mucus/position are ordered enums; symptoms are many-to-many per day.

---

## 3. Clinically Important Signals to Flag

The app should surface (not diagnose) these using reputable thresholds and route users to "see a clinician":

| Signal | Threshold / trigger | Source |
|---|---|---|
| **Very heavy bleeding (menorrhagia)** | Soaking ≥1 pad/tampon **per hour for several consecutive hours**; **bleeding >7 days**; passing **clots ≥ a quarter (~2.5 cm)**; needing double protection or changing overnight; classic volume def **>80 mL/cycle** | [ACOG](https://www.acog.org/womens-health/faqs/heavy-menstrual-bleeding), [Cleveland Clinic](https://my.clevelandclinic.org/health/diseases/17734-menorrhagia-heavy-menstrual-bleeding) |
| **Irregular cycles** | Cycle-to-cycle variation shifting by **≥7–9 days**; adult cycles falling outside **21–35 d** consistently | [Cleveland/ACOG](https://my.clevelandclinic.org/health/diseases/17734-menorrhagia-heavy-menstrual-bleeding) |
| **Unusually short / long cycles** | **<21 d** or **>35 d** (adults); adolescents up to **45 d** can be normal | [ACOG adolescent / AFP](https://www.aafp.org/pubs/afp/issues/2020/0515/p633.html) |
| **Missed period / amenorrhea (secondary)** | **No period for ≥3 months** in someone who previously menstruated → evaluate (pregnancy test first) | [ACOG](https://www.acog.org/womens-health/faqs/amenorrhea-absence-of-periods), [Cleveland Clinic](https://my.clevelandclinic.org/health/diseases/3924-amenorrhea) |
| **Primary amenorrhea** | **No first period by age 15**, or within 5 years of breast development | [Cleveland Clinic](https://my.clevelandclinic.org/health/diseases/3924-amenorrhea) |
| **Possible PCOS** | **Oligo/anovulation** + hyperandrogenism (acne, hirsutism, hair loss). Formal dx = **Rotterdam: 2 of 3** | [Mayo Clinic PCOS](https://www.mayoclinic.org/diseases-conditions/pcos/symptoms-causes/syc-20353439) |
| **Possible endometriosis** | Severe/progressive dysmenorrhea, chronic pelvic pain, pain with sex, pain not relieved by NSAIDs, heavy bleeding | [Bioscientifica review](https://ec.bioscientifica.com/view/journals/ec/13/2/EC-23-0431.xml) |
| **Possible thyroid disorder** | Cycle changes + hypo/hyperthyroid symptoms (fatigue, weight change, temperature intolerance) | [Bioscientifica review](https://ec.bioscientifica.com/view/journals/ec/13/2/EC-23-0431.xml) |
| **Pregnancy signals** | Missed period + unprotected sex in fertile window → prompt test | [ACOG amenorrhea](https://www.acog.org/womens-health/faqs/amenorrhea-absence-of-periods) |
| **Urgent** | Bleeding causing dizziness/shortness of breath (anemia), bleeding between periods or after sex, post-menopausal bleeding | [ACOG](https://www.acog.org/womens-health/faqs/heavy-menstrual-bleeding) |

**Design constraint:** flags must be phrased as "this may be worth discussing with a clinician," never a diagnosis, to stay clear of medical-device regulation unless deliberately pursuing clearance (see §4).

---

## 4. Prediction Methods & Their Limits

| Method | How it works | Accuracy / limits |
|---|---|---|
| **Calendar / rhythm** | Predicts fertile window from historical cycle length | Weakest; fails with any cycle irregularity; purely retrospective statistics |
| **BBT** | Sustained **0.5–1°F rise** confirms ovulation | **Confirms ovulation only after it happens** — cannot predict window prospectively; sensitive to sleep, illness, alcohol |
| **Cervical mucus (Billings)** | Egg-white, stretchy mucus = peak fertility | Subjective; affected by infection, semen, lubricants |
| **Symptothermal** | **Combines BBT + mucus (+ position/LH)** — most reliable FABM | Perfect use **~0.4%** failure/yr; **typical use ~2%** ([StatPearls](https://www.ncbi.nlm.nih.gov/books/NBK564316/), [ACOG FABM](https://www.acog.org/womens-health/faqs/fertility-awareness-based-methods-of-family-planning)) |
| **Modern app algorithms** | Statistical/ML over cycle length, BBT, LH, mucus; some use wearable temp | Accuracy degrades sharply for irregular/PCOS/perimenopause users and sparse loggers; predictions are probabilistic ranges |

**Regulatory line (critical):** A period/fertility app is **not contraception** unless FDA-cleared. **Natural Cycles is the first and only FDA-cleared app cleared for contraception (2018)**, using BBT + LH. ([KFF](https://www.kff.org/womens-health-policy/fertility-awareness-based-methods-to-prevent-pregnancy/)) Any "prevent pregnancy" claim without clearance is a regulatory and safety problem — default framing should be "prediction for awareness," not birth control.

---

## 5. Life-Stage Modes

Each mode changes which fields are surfaced, which flags fire, and how prediction behaves:

- **Teen / first period (menarche):** Widen "normal" to **21–45 day cycles**; expect irregularity for ~2–3 years. Suppress premature "irregular cycle" alarms. Flag: **no first period by 15**. Educational-heavy UI.
- **Trying to conceive (TTC):** Surface all fertility biomarkers (BBT, mucus, cervical position, LH/OPK), highlight the 6-day fertile window and peak 2 days. Emphasize probabilistic conception rates.
- **Pregnancy:** Switch off cycle prediction; track by gestational week, symptoms, appointments; flag bleeding as needing evaluation.
- **Postpartum:** Cycles return unpredictably (esp. breastfeeding); disable normal-range flags; do **not** imply contraceptive protection.
- **Perimenopause:** Expect cycles to shift by **≥7 days**, then become erratic before stopping; track hot flashes, sleep, mood. Flag **post-menopausal bleeding** as always warranting evaluation. ([Cleveland Clinic](https://my.clevelandclinic.org/health/diseases/21608-perimenopause))
- **Birth control / period suppression:** Track method + adherence; model withdrawal bleeds vs true periods; suppress fertility-prediction UI (invalid on hormonal contraception).

---

### Data-model takeaways for the team
1. **Cycle object** = {start, end, length, flow-per-day, ovulation-estimate (with confidence), fertile-window range}. Store predictions as **ranges + confidence**, never single dates.
2. **Daily log** = many-to-many symptom entries on enumerated scales; BBT/weight numeric; mucus/LH/position ordered enums.
3. **Flag engine** = rule set keyed to the §3 thresholds, always outputting "discuss with clinician," never a diagnosis.
4. **Mode switch** = changes normal-range bounds, active fields, and prediction validity (§5).
5. **Regulatory guardrail** = no contraceptive claims without FDA clearance (§4).
