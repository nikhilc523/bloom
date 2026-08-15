# Period-Tracking App — Apple Platform Technical Architecture Brief

Target: SwiftUI app, iPhone-first (iOS 17.0+ baseline, some features gated to iOS 18/17.4). Serverless via CloudKit where possible.

---

## 1. HealthKit — Two-Way Sync with Apple's Cycle Tracking

HealthKit is the integration point that lets the app read from and write to the same store that powers Apple's built-in **Cycle Tracking**. Reproductive-health samples written to HealthKit surface in the Health app's Cycle Tracking, and vice versa — so a correct HealthKit implementation *is* the two-way sync; there is no separate Cycle Tracking API.

### Relevant type identifiers

All reproductive-health cycle data is modeled as **`HKCategoryType`** (discrete enum-valued) except basal body temperature, which is a **`HKQuantityType`** (numeric).

| Concept | Identifier | Type | Value enum |
|---|---|---|---|
| Menstrual flow | [`menstrualFlow`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/menstrualflow) | `HKCategoryType` | `HKCategoryValueVaginalBleeding` (iOS 18+; formerly `HKCategoryValueMenstrualFlow`) |
| Ovulation test result | [`ovulationTestResult`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/1615252-ovulationtestresult) | `HKCategoryType` | [`HKCategoryValueOvulationTestResult`](https://developer.apple.com/documentation/healthkit/hkcategoryvalueovulationtestresult) (`.negative`, `.luteinizingHormoneSurge`, `.indeterminate`, `.estrogenSurge`) |
| Cervical mucus quality | [`cervicalMucusQuality`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/cervicalmucusquality) | `HKCategoryType` | [`HKCategoryValueCervicalMucusQuality`](https://developer.apple.com/documentation/healthkit/hkcategoryvaluecervicalmucusquality) (`.dry`, `.sticky`, `.creamy`, `.watery`, `.eggWhite`) |
| Basal body temperature | [`basalBodyTemperature`](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/basalbodytemperature) | `HKQuantityType` | numeric, unit `HKUnit.degreeCelsius()` |
| Sexual activity | [`sexualActivity`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/sexualactivity) | `HKCategoryType` | value `.notApplicable`; optional metadata key [`HKMetadataKeySexualActivityProtectionUsed`](https://developer.apple.com/documentation/healthkit/hkmetadatakeysexualactivityprotectionused) |
| Intermenstrual bleeding (spotting) | [`intermenstrualBleeding`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/intermenstrualbleeding) | `HKCategoryType` | `.notApplicable` |
| Pregnancy | [`pregnancy`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/pregnancy) | `HKCategoryType` | `.notApplicable` |
| Contraceptive | [`contraceptive`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/contraceptive) | `HKCategoryType` | `HKCategoryValueContraceptive` |
| Lactation | [`lactation`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/lactation) | `HKCategoryType` | `.notApplicable` |
| Pregnancy test result | [`pregnancyTestResult`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/pregnancytestresult) | `HKCategoryType` | `HKCategoryValuePregnancyTestResult` |
| Progesterone test result | [`progesteroneTestResult`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/progesteronetestresult) | `HKCategoryType` | `HKCategoryValueProgesteroneTestResult` |

Cycle-deviation "symptoms" surfaced by Cycle Tracking (iOS 16+): [`persistentIntermenstrualBleeding`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/persistentintermenstrualbleeding), [`infrequentMenstrualCycles`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/infrequentmenstrualcycles), [`irregularMenstrualCycles`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/irregularmenstrualcycles), [`prolongedMenstrualPeriods`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/prolongedmenstrualperiods) — all `HKCategoryType`.

Full list: [`HKCategoryTypeIdentifier`](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier). Note menstrual flow samples typically carry the metadata key [`HKMetadataKeyMenstrualCycleStart`](https://developer.apple.com/documentation/healthkit/hkmetadatakeymenstrualcyclestart) (`Bool`) to mark the first day of a cycle — set this so your writes properly anchor Apple's cycle predictions.

### Reading and writing

- Entry point: [`HKHealthStore`](https://developer.apple.com/documentation/healthkit/hkhealthstore). Guard with [`HKHealthStore.isHealthDataAvailable()`](https://developer.apple.com/documentation/healthkit/hkhealthstore/1614180-ishealthdataavailable).
- **Write:** build an [`HKCategorySample`](https://developer.apple.com/documentation/healthkit/hkcategorysample) (e.g. `HKCategorySample(type:value:start:end:metadata:)` with the flow value) or [`HKQuantitySample`](https://developer.apple.com/documentation/healthkit/hkquantitysample) for basal temperature, then `healthStore.save(_:)`.
- **Read:** [`HKSampleQuery`](https://developer.apple.com/documentation/healthkit/hksamplequery) for snapshots; [`HKAnchoredObjectQuery`](https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery) for incremental delta sync (persist the `HKQueryAnchor`); [`HKObserverQuery`](https://developer.apple.com/documentation/healthkit/hkobserverquery) + [`enableBackgroundDelivery(for:frequency:withCompletion:)`](https://developer.apple.com/documentation/healthkit/hkhealthstore/1614175-enablebackgrounddelivery) to get woken when the user (or Apple's Health app) logs new cycle data. This observer/anchored pattern is what makes the sync genuinely two-way and near-real-time.

### Permissions, privacy prompts, entitlements

- Add the **HealthKit** capability in Xcode → adds the `com.apple.developer.healthkit` entitlement. For background wake-ups also enable [`com.apple.developer.healthkit.background-delivery`](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit.background-delivery).
- Request access with [`requestAuthorization(toShare:read:)`](https://developer.apple.com/documentation/healthkit/hkhealthstore/1614152-requestauthorization) — `toShare` = write, `read` = read; each type is authorized individually.
- **Info.plist strings are mandatory** or the app crashes on request: [`NSHealthShareUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nshealthshareusagedescription) (read) and [`NSHealthUpdateUsageDescription`](https://developer.apple.com/documentation/bundleresources/information-property-list/nshealthupdateusagedescription) (write).
- Privacy model: iOS shows a per-type toggle sheet. **You cannot query whether the user granted *read* access** ([`authorizationStatus(for:)`](https://developer.apple.com/documentation/healthkit/hkhealthstore/1614154-authorizationstatus) only reports write status) — design for "no data returned" rather than "denied." Reference: [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data) and [Setting up HealthKit](https://developer.apple.com/documentation/healthkit/setting-up-healthkit).

---

## 2. iCloud Sync — CloudKit vs Core Data+CloudKit vs SwiftData

### The options

- **CloudKit direct** ([`CKRecord`](https://developer.apple.com/documentation/cloudkit/ckrecord) in [`CKContainer.privateCloudDatabase`](https://developer.apple.com/documentation/cloudkit/ckcontainer)) — max control, most code. Consider [`CKSyncEngine`](https://developer.apple.com/documentation/cloudkit/cksyncengine) (iOS 17+) if going raw.
- **[`NSPersistentCloudKitContainer`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)** (Core Data + CloudKit) — automatic private-DB mirroring *and* first-class **sharing** APIs ([`share(_:to:completion:)`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746834-share), [`acceptShareInvitations`](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer/3746829-acceptshareinvitations)). See [Sharing Core Data objects between iCloud users](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users).
- **SwiftData + CloudKit** — `ModelConfiguration(cloudKitDatabase:)` gives automatic **private-database** sync with almost no code, but **SwiftData does not support the CloudKit public or shared database.** There is no first-party SwiftData sharing API. See [Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices).

### Recommendation

**(a) Single user's private cycle data across her own devices → SwiftData + CloudKit private database.** Lowest-effort, native to SwiftUI, automatic conflict resolution and mirroring. Requirements: iCloud capability with CloudKit, an iCloud container, and the **Background Modes → Remote notifications** capability (CloudKit uses silent pushes to trigger sync). SwiftData/CloudKit constraints apply: every model property must be optional or have a default, no `@Attribute(.unique)`, relationships must be optional.

**(b) Selectively sharing a subset with a partner's separate iCloud account → CKShare on a custom zone.** Because SwiftData can't share, do this via **`NSPersistentCloudKitContainer`** or **direct CloudKit**. Concretely:

- A **[`CKShare`](https://developer.apple.com/documentation/cloudkit/ckshare)** is a special record saved to the owner's private database that defines *what* is shared, *who* the participants are, and their permissions ([`CKShare.ParticipantPermission`](https://developer.apple.com/documentation/cloudkit/ckshare/participantpermission) — `.readOnly` / `.readWrite`).
- **You cannot share from the default zone.** Put the shareable subset (e.g. a `PartnerSpace` record graph: current cycle summary, predicted dates, pinned notes) in a **custom [`CKRecordZone`](https://developer.apple.com/documentation/cloudkit/ckrecordzone)**. Two share models: (1) a **rooted share** on a root `CKRecord` plus its hierarchy, or (2) a **zone-wide share** (initialize `CKShare(recordZoneID:)`) which shares the whole custom zone — the cleaner choice for "everything in the partner space." A zone-wide share is identifiable by `recordID.recordName == CKRecordNameZoneWideShare`.
- Present invites with [`UICloudSharingController`](https://developer.apple.com/documentation/uikit/uicloudsharingcontroller) (or a share `URL`). The partner accepts, and the shared graph then appears in **their** [`sharedCloudDatabase`](https://developer.apple.com/documentation/cloudkit/ckcontainer/1399189-sharedclouddatabase). Each user's private cycle data stays in her own private DB; only the explicitly shared zone crosses accounts. This is exactly the isolation you want for the partner feature.

Architecture verdict: **SwiftData private-DB sync as the default for the owner, plus a separate CloudKit-direct (or Core Data) layer for the shared partner zone.** Keep the two concerns in separate stores/containers so the sharing complexity doesn't infect the main model. (SwiftData is not yet a viable single-stack answer to the partner requirement — confirmed limitation as of iOS 18.)

---

## 3. Notifications — Local, Push, and Partner-to-Partner via CloudKit

### Local notifications (predictions/reminders)

Use [`UNUserNotificationCenter`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter). Request via [`requestAuthorization(options:)`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/1649527-requestauthorization); schedule [`UNNotificationRequest`](https://developer.apple.com/documentation/usernotifications/unnotificationrequest) with a [`UNCalendarNotificationTrigger`](https://developer.apple.com/documentation/usernotifications/uncalendarnotificationtrigger) for "period starts in 2 days," fertile window, pill reminders, etc. All prediction/reminder logic can run entirely on-device — no server needed.

### Interruption levels / time-sensitive

Set [`UNMutableNotificationContent.interruptionLevel`](https://developer.apple.com/documentation/usernotifications/unmutablenotificationcontent/3747258-interruptionlevel) using [`UNNotificationInterruptionLevel`](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel): `.passive`, `.active`, `.timeSensitive`, `.critical`. Health reminders that should break through Focus are good candidates for **`.timeSensitive`** — this requires the [`com.apple.developer.usernotifications.time-sensitive`](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.usernotifications.time-sensitive) entitlement. `.critical` needs a special Apple-granted entitlement and is not appropriate here.

### Partner-to-partner messaging & pinned notes — no custom backend

You can deliver partner→partner updates **fully serverless** using CloudKit push subscriptions:

- **[`CKQuerySubscription`](https://developer.apple.com/documentation/cloudkit/ckquerysubscription)** — fires when a record matching a predicate is created/updated/deleted (private & public DBs).
- **[`CKDatabaseSubscription`](https://developer.apple.com/documentation/cloudkit/ckdatabasesubscription)** — fires on *any* change in a database; the standard choice for the **shared** database. Note: `CKDatabaseSubscription` only works with **custom zones**, not the default zone — which aligns with the custom-zone requirement from §2.
- Configure delivery with [`CKSubscription.NotificationInfo`](https://developer.apple.com/documentation/cloudkit/cksubscription/notificationinfo): set `shouldSendContentAvailable = true` for a **silent** push that wakes the app to fetch changes (requires Background Modes → Remote notifications), or set `alertBody`/`title` for a **visible** push. CloudKit's own servers send these via APNs — Apple *is* your push server.

**Pinned-notes flow without a backend:** Partner A writes/edits a `PinnedNote` `CKRecord` in the shared custom zone → CloudKit fires the `CKDatabaseSubscription` → Partner B's device receives a silent push, calls [`CKFetchRecordZoneChangesOperation`](https://developer.apple.com/documentation/cloudkit/ckfetchrecordzonechangesoperation) (persist the `serverChangeToken`), merges the note, and raises a local `UNUserNotificationCenter` alert ("Your partner pinned a note"). This gives near-real-time partner messaging and note sync with **zero custom infrastructure**. Reference: [Subscribing to record changes with CloudKit](https://developer.apple.com/documentation/cloudkit/subscribing-to-record-changes-with-cloudkit). Caveat: silent pushes are throttled/coalesced by APNs, so treat them as "hints to sync," not guaranteed 1:1 delivery — pair with a fetch-on-foreground.

---

## 4. Widgets & Live Activities

### WidgetKit — home screen & Lock Screen

[WidgetKit](https://developer.apple.com/documentation/widgetkit) in a Widget Extension. A [`TimelineProvider`](https://developer.apple.com/documentation/widgetkit/timelineprovider) generates entries (current cycle day, days to next period, fertile-window flag). Support home-screen families (`.systemSmall/.systemMedium`) and **Lock Screen** families ([`.accessoryCircular`, `.accessoryRectangular`, `.accessoryInline`](https://developer.apple.com/documentation/widgetkit/widgetfamily)) — a circular Lock Screen widget showing cycle-day progress is a strong fit. Share data from the app to the widget via an **App Group** container. Interactive widgets (iOS 17) can log "period started" via [`AppIntent`](https://developer.apple.com/documentation/appintents/appintent). Refresh cadence is timeline-driven; call [`WidgetCenter.shared.reloadTimelines(ofKind:)`](https://developer.apple.com/documentation/widgetkit/widgetcenter) when data changes.

### Live Activity / Dynamic Island — "period countdown"

Use [ActivityKit](https://developer.apple.com/documentation/activitykit) + WidgetKit; UI is SwiftUI. A [`Live Activity`](https://developer.apple.com/documentation/activitykit/activity) renders on the Lock Screen, in the **Dynamic Island**, and in StandBy. Requires `NSSupportsLiveActivities = true` in Info.plist. Update locally with [`Activity.update(_:)`](https://developer.apple.com/documentation/activitykit/activity/update(_:)) or remotely via APNs.

**Assessment:** Live Activities are designed for **short, bounded, ongoing events** (delivery ETA, timer, game). A multi-day "period countdown" runs for days/weeks — well beyond the intended lifetime (system limits them to ~8h active, ~12h total on Lock Screen before dismissal). So a *persistent* countdown Live Activity is a poor fit. Recommendation: **use a Lock Screen WidgetKit widget for the always-on countdown**, and reserve a Live Activity for a genuinely short window — e.g. the last 24–48h before a predicted period, or an active-flow day tracker. The Dynamic Island `.compactTrailing` showing "3d" is a nice touch only for that short pre-period window.

---

## 5. Tech Stack Recommendation

**Stack: SwiftUI + SwiftData + CloudKit, targeting iOS 17.0 (adopt iOS 18 APIs conditionally).**

- **UI:** SwiftUI throughout (also required for WidgetKit / Live Activities).
- **Persistence + private sync:** SwiftData with `ModelConfiguration(cloudKitDatabase: .automatic)` for the owner's cross-device private data. iOS 17 is the SwiftData baseline; if you need any of the partner-sharing plumbing to be simpler, iOS 18 has small SwiftData improvements but *still no sharing*.
- **Partner sharing:** separate CloudKit-direct (or `NSPersistentCloudKitContainer`) layer with a custom zone + `CKShare` — see §2b.
- **Notifications:** `UNUserNotificationCenter` local + CloudKit `CKDatabaseSubscription` silent pushes — see §3.
- **Backend:** **Fully serverless via CloudKit is sufficient.** Private sync, partner sharing, and partner messaging are all covered by CloudKit + APNs at no server cost. A lightweight backend is only warranted if you later add: non-Apple partners (Android/web), server-side analytics/ML predictions, or account features beyond iCloud. Start serverless; the CloudKit design doesn't preclude adding a backend later.

### App Store / privacy requirements (must-do for review)

- **Guideline 5.1.3** — health/fitness data (incl. HealthKit) may **not** be used or disclosed for advertising or data-mining; only for health management, and only with permission. Apps must **not write false data** to HealthKit and **must not store health data in iCloud** *without proper handling* — CloudKit is acceptable when data is the user's own and consented, but do not push HealthKit-sourced data to third-party servers. ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)).
- **Privacy policy required** for any app using HealthKit / collecting health data, plus explicit user consent.
- **Guideline 5.1.1** — request permission with clear purpose strings; the `NSHealth*UsageDescription` strings must be specific and honest.
- **HealthKit review specifics:** apps using HealthKit must clearly identify HealthKit integration in the description; may not use HealthKit data for purposes other than health/fitness/medical research; must have a privacy policy. See [Protecting user privacy (HealthKit)](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) and [Health & Fitness](https://developer.apple.com/health-fitness/).
- **Privacy nutrition label / App Privacy details** in App Store Connect must declare Health & Fitness data collection, linkage, and tracking. Encrypt at rest; consider that reproductive-health data is legally sensitive — minimize collection and keep processing on-device where possible.

---

### Sources
- [HKCategoryTypeIdentifier](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier)
- [ovulationTestResult](https://developer.apple.com/documentation/healthkit/hkcategorytypeidentifier/1615252-ovulationtestresult)
- [Authorizing access to health data](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data)
- [Setting up HealthKit](https://developer.apple.com/documentation/healthkit/setting-up-healthkit)
- [HealthKit background delivery entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.healthkit.background-delivery)
- [NSPersistentCloudKitContainer](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)
- [Sharing Core Data objects between iCloud users](https://developer.apple.com/documentation/coredata/sharing-core-data-objects-between-icloud-users)
- [SwiftData: Syncing model data across a person's devices](https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices)
- [CKShare](https://developer.apple.com/documentation/cloudkit/ckshare) · [CKRecordZone](https://developer.apple.com/documentation/cloudkit/ckrecordzone) · [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine)
- [CKQuerySubscription](https://developer.apple.com/documentation/cloudkit/ckquerysubscription) · [CKDatabaseSubscription](https://developer.apple.com/documentation/cloudkit/ckdatabasesubscription) · [Subscribing to record changes with CloudKit](https://developer.apple.com/documentation/cloudkit/subscribing-to-record-changes-with-cloudkit)
- [UNUserNotificationCenter](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter) · [UNNotificationInterruptionLevel](https://developer.apple.com/documentation/usernotifications/unnotificationinterruptionlevel)
- [WidgetKit](https://developer.apple.com/documentation/widgetkit) · [ActivityKit](https://developer.apple.com/documentation/activitykit)
- [Get the most out of CloudKit Sharing (Apple Tech Talk)](https://developer.apple.com/videos/play/tech-talks/10874/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) · [Protecting user privacy (HealthKit)](https://developer.apple.com/documentation/healthkit/protecting-user-privacy) · [Health & Fitness](https://developer.apple.com/health-fitness/)
