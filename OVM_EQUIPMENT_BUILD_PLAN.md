# OVM Equipment --- Codex Build Plan

**Status:** implementation plan\
**Target:** native iOS application\
**Working product name:** **OVM Equipment**\
**Reference implementation / visual source:**
`data-project2/OVMDivePlanner`\
**Product proposition:** **Your equipment. Your device. Your data.**\

**Implementation repository:** `data-project2/OVMEquipment`  
**Reference repository (read-only):** `data-project2/OVMDivePlanner`

### Repository boundary

OVM Equipment is a **separate product and must be built in a separate Git repository and separate Xcode project**.

```text
data-project2/
├── OVMDivePlanner   # existing planner; read-only reference during Equipment work
└── OVMEquipment     # new Equipment application
```

Codex must never implement OVM Equipment inside `OVMDivePlanner`. The Planner repository is used only to inspect approved OVM visual conventions, assets, project conventions, and reusable patterns.

The repositories have independent Git history, Xcode projects, bundle identifiers, release/version lifecycles, tests/CI, privacy manifests, and App Store builds. Do not create a monorepo for the two applications.

Shared code should not be extracted merely because similar code exists. Initially reproduce only the small, stable OVM design tokens/assets needed by Equipment. If multiple OVM apps later need the same evolving UI components, extract proven shared concerns into a dedicated Swift Package such as `OVMDesignSystem`. Do not use shared packages to couple Equipment to Planner decompression or gas engines.


------------------------------------------------------------------------

## 1. Product intent

OVM Equipment is a privacy-first, local-only equipment management
application for divers.

The first release should answer one primary question:

> **What equipment needs attention before my next dive or trip?**

The application is not intended to become a cloud inventory service,
social platform, dive-shop portal, or manufacturer database. The
local-only architecture is a deliberate product feature.

### Core principles

1.  **Local first and local only**
    -   No account.
    -   No login.
    -   No OVM backend.
    -   No central equipment history.
    -   No analytics or tracking SDKs.
    -   Equipment data, serial numbers, photographs, OCR results,
        maintenance dates, and notification preferences remain on the
        device.
2.  **Fast data entry**
    -   Manual entry must always work.
    -   Equipment photographs may be stored locally.
    -   Serial numbers should be scannable with the camera.
    -   OCR results must always be confirmed by the user before
        persistence.
    -   Brand recognition is optional and must never block equipment
        creation.
3.  **Maintenance before inventory**
    -   Inventory is the data foundation.
    -   The primary user value is maintenance awareness.
    -   The app should make `OK`, `Approaching`, and `Due / Expired`
        immediately understandable.
4.  **OVM family consistency**
    -   Reuse the visual language of OVM Dive Planner.
    -   Reuse the OVM logo/app-icon source assets where legally and
        technically appropriate.
    -   Do not redesign the OVM brand.

------------------------------------------------------------------------

## 2. Reference application findings

OVM Dive Planner is a native SwiftUI iOS application with a Models /
Views / ViewModels / Utils structure and iOS 16 as its documented
deployment target.

Use its visual system as the source of truth. In particular, mirror the
existing `OVMTheme` values:

``` swift
accent          = RGB(91, 206, 250)   // #5BCEFA
background      = RGB(18, 31, 52)     // #121F34
card            = RGB(27, 43, 69)     // #1B2B45, existing opacity behavior
border          = RGB(48, 70, 106)    // #30466A
textPrimary     = RGB(212, 220, 232)  // #D4DCE8
textSecondary   = RGB(158, 178, 202)  // #9EB2CA
textTertiary    = RGB(112, 132, 160)  // #7084A0
danger          = RGB(244, 91, 105)   // #F45B69
warningBackground = RGB(42, 21, 32)   // #2A1520
tableHover      = RGB(31, 49, 78)     // #1F314E
```

Do not copy decompression, gas-planning, CCR, VPM-B, Bühlmann, mixer, or
other dive-planning engines into OVM Equipment. This is a separate app
sharing brand language, not planner logic.

------------------------------------------------------------------------

## 3. Repository and project bootstrap

Create and use:

```text
GitHub repository: data-project2/OVMEquipment
Local repository:  /Users/ferryouwerkerk/Documents/OVMEquipment
Xcode project:      OVMEquipment.xcodeproj
App target:         OVMEquipment
Test target:        OVMEquipmentTests
```

The final bundle identifier and signing configuration remain explicit product decisions and must not be guessed by Codex.

Recommended repository root:

```text
OVMEquipment/
├── .codex/
├── AGENTS.md
├── README.md
├── OVM_EQUIPMENT_BUILD_PLAN.md
├── ADR/
├── OVMEquipment.xcodeproj
├── OVMEquipment/
└── OVMEquipmentTests/
```

Repository rules:

- `OVMEquipment` is the only writable product repository for Equipment implementation.
- `OVMDivePlanner` is a read-only reference repository.
- Never place Equipment source files under the Planner repository.
- Never reuse the Planner bundle identifier.
- Never couple Equipment releases to Planner releases.
- Never import Planner engine source files into Equipment.
- When visual behavior is unclear, inspect Planner and document the source being followed.
- Copy only the minimum stable visual tokens/assets required initially.
- Any future shared Swift package requires a documented cross-product need and an ADR.

A possible later structure is:

```text
OVMDivePlanner ─────┐
                    ├── OVMDesignSystem
OVMEquipment ───────┘
```

`OVMDesignSystem` may eventually contain colors, typography, cards, buttons, status badges, and approved brand assets. It must not become a route for coupling Equipment to Planner's decompression engines.

---

## 4. Recommended technical baseline

### Platform

Build **OVM Equipment as a separate native SwiftUI iOS app/repository**,
rather than adding an Equipment tab to OVM Dive Planner.

Recommended baseline:

-   SwiftUI
-   Swift
-   iOS 17+ if a new project can adopt it without product constraints
-   SwiftData for local structured persistence
-   PhotosUI for choosing an existing image
-   AVFoundation / camera APIs for image capture where required
-   Vision / VisionKit for on-device OCR
-   UserNotifications for local reminders
-   XCTest / Swift Testing as appropriate to the selected Xcode
    toolchain

If product compatibility requires iOS 16 to match OVM Dive Planner,
Codex must stop before implementation and propose the Core Data
alternative instead of silently changing persistence architecture.

### Why SwiftData

For a new local-only application, SwiftData provides a simple
persistence layer with migrations and SwiftUI integration. It also makes
the privacy boundary clear: the app does not need a server to perform
CRUD, maintenance calculations, or reminders.

### Storage boundary

Persist locally:

-   equipment records;
-   maintenance dates;
-   regulator component relationships;
-   notes;
-   local image references or image data;
-   confirmed serial numbers;
-   notification preferences.

Do **not** persist unconfirmed OCR text as authoritative equipment data.

------------------------------------------------------------------------

## 5. Domain model

Prefer a common `EquipmentItem` abstraction plus type-specific details
only where that improves maintainability. Do not over-engineer
inheritance.

### 4.1 Common equipment fields

Every item should support:

``` text
id
equipmentType
name
manufacturer
model (optional where not relevant)
serialNumber (optional)
photo
notes
createdAt
updatedAt
```

`equipmentType` initially supports:

``` text
cylinder
regulator
```

Design the enum so later additions do not require redesigning the whole
application:

``` text
ccr
bcdWing
drysuit
dpv
computer
light
other
```

Do not implement those later types in MVP.

### 4.2 Cylinder

Store:

``` text
description / name
manufacturer
cylinder type
material
volume
working pressure
serial number
manufacture date
VIP date
next VIP due date
hydrostatic-test date
next hydro due date
photo
notes
```

Recommended enums:

``` text
CylinderMaterial:
- steel
- aluminium
- composite
- other

CylinderType:
- backGas
- stage
- deco
- bailout
- pony
- suitInflation
- other
```

Do not hard-code legal inspection intervals globally. Inspection rules
differ by jurisdiction, cylinder type, use, and local practice. In MVP,
due dates are user-entered or derived only from an explicitly
user-selected interval.

### 4.3 Regulator

Store:

``` text
description / name
manufacturer
model
serial number
component role
associated regulator set
last service date
next service date
service interval
photo
notes
```

A regulator set must be able to represent:

``` text
first stage
primary second stage
alternate second stage
optional additional second stage
```

Do not assume a first stage and second stage share one serial number.

Recommended model:

``` text
RegulatorSet
  id
  name
  notes

RegulatorComponent
  id
  setId
  role
  manufacturer
  model
  serialNumber
  lastServiceDate
  nextServiceDate
  serviceIntervalMonths
  photo
  notes
```

The UI may present a regulator set as one equipment card while
preserving component-level serial and service data.

------------------------------------------------------------------------

## 6. Maintenance model

Maintenance status must be deterministic and unit-testable. Do not
calculate status inside SwiftUI views.

### Status

``` swift
enum MaintenanceStatus {
    case ok
    case approaching
    case due
    case unknown
}
```

Suggested semantics:

``` text
unknown:
    no due date exists

due:
    dueDate <= today

approaching:
    today < dueDate <= today + configured warning window

ok:
    dueDate > today + configured warning window
```

Use calendar-day comparisons, not fragile second-based arithmetic.

### Maintenance events

MVP supports:

``` text
Cylinder:
- VIP
- Hydrostatic test

Regulator:
- Service
```

A single item may therefore have multiple maintenance events. The
equipment card should display the most urgent status while the detail
screen shows each event independently.

### Important guardrail

The app must not claim that an item is safe to dive merely because its
stored service date is current.

Use wording such as:

``` text
Maintenance current
Service approaching
Service due
Date not set
```

Avoid:

``` text
Safe
Dive safe
Certified safe
Guaranteed serviceable
```

------------------------------------------------------------------------

## 7. Notification design

Use **local notifications only**.

### User preferences

Default selectable lead times:

``` text
90 days
60 days
30 days
14 days
Custom
```

Consider allowing more than one reminder for the same maintenance event,
for example 60 and 14 days.

### Notification examples

``` text
VIP due in 30 days
Hydro test due in 60 days
Regulator service due next month
Regulator service is due
```

### Notification behavior

Whenever an item or maintenance date changes:

1.  cancel pending notifications belonging to the changed event;
2.  calculate applicable reminder dates;
3.  schedule future local notifications;
4.  do not schedule dates already in the past;
5.  schedule a due-date notification if enabled;
6.  retain notification identifiers so they can be reliably replaced or
    removed.

Request notification permission contextually, not on first launch. Ask
when the user enables reminders or creates the first due date that could
use one.

------------------------------------------------------------------------

## 8. Equipment photo architecture

### MVP

Allow:

-   take photo;
-   select photo from photo library;
-   replace photo;
-   remove photo.

The stored photo belongs to the equipment record and remains local.

### Storage recommendation

Do not put large full-resolution photographs directly into frequently
queried model rows.

Preferred design:

``` text
Application Support/
    EquipmentImages/
        <equipment-id>/
            primary.jpg
```

Persist the relative file reference in the model.

When saving:

-   correct orientation;
-   resize to a sensible maximum dimension;
-   compress to a sensible JPEG/HEIF quality;
-   strip unnecessary metadata where practical;
-   do not upload anywhere.

When deleting an equipment item, delete its managed image files.

------------------------------------------------------------------------

## 9. Serial-number scanning

### User flow

On the equipment editor:

``` text
Serial number
[ manual text field ]  [ Scan ]
```

Tapping **Scan**:

1.  opens camera scanner;
2.  user frames serial-number label / engraving;
3.  app captures or analyzes the image locally;
4.  Vision extracts candidate text;
5.  app ranks likely serial-number candidates;
6.  app shows the candidate to the user;
7.  user can edit it;
8.  only after **Use Serial Number** is tapped is it written to the
    equipment record.

### OCR pipeline

Use Apple Vision on-device text recognition.

Suggested pipeline:

``` text
camera frame / still image
        ↓
VNRecognizeTextRequest
        ↓
recognized text observations
        ↓
normalization
        ↓
candidate scoring
        ↓
confirmation UI
        ↓
user-approved serial number
        ↓
local persistence
```

Normalization may:

-   trim whitespace;
-   join visually split groups when confidence is high;
-   preserve hyphens and slashes;
-   normalize obvious whitespace;
-   preserve original recognized text for the confirmation screen.

Do not silently convert ambiguous `O/0`, `I/1`, `S/5`, `B/8`, etc.

### Candidate scoring

Candidate scoring can favor text:

-   near labels such as `SERIAL`, `SER`, `S/N`, `SN`, `NO`, `NUMBER`;
-   containing a plausible alphanumeric mix;
-   with a reasonable length;
-   occupying a prominent OCR bounding box.

It must remain heuristic. User confirmation is mandatory.

### Failure behavior

OCR failure must never prevent item creation.

Offer:

``` text
Try Again
Enter Manually
Cancel
```

------------------------------------------------------------------------

## 10. Optional manufacturer / brand recognition

Brand recognition is **Phase 2**, behind a feature boundary.

### Preferred privacy-preserving architecture

Use a layered local approach:

``` text
Captured image
     │
     ├── Vision OCR
     │      ↓
     │   recognized words
     │      ↓
     │   local manufacturer alias matcher
     │
     └── optional on-device Core ML classifier
            ↓
        candidate brand(s)
             ↓
       confidence threshold
             ↓
       user confirmation
             ↓
       manufacturer field
```

### Layer 1 --- OCR brand matching

Start here.

Maintain a bundled local alias catalog, for example:

``` json
{
  "Scubapro": ["SCUBAPRO"],
  "Apeks": ["APEKS"],
  "Mares": ["MARES"],
  "Halcyon": ["HALCYON"]
}
```

Match OCR words against aliases using conservative normalization.

Advantages:

-   fully offline;
-   explainable;
-   small;
-   easy to update with app releases;
-   no training dataset required.

### Layer 2 --- on-device image classifier

Only add if OCR-based matching proves insufficient.

Possible implementation:

-   Create ML / Core ML image classifier;
-   trained on legally usable product/logo images;
-   shipped inside the app;
-   inference entirely on device;
-   output top candidates with confidence;
-   user confirms the brand.

### Guardrails for brand recognition

-   Never send equipment images to a remote AI/vision API in the
    privacy-first product.
-   Never auto-save a predicted brand.
-   Do not infer model number from weak visual similarity.
-   Do not present predictions as facts.
-   If confidence is below threshold, show no automatic suggestion.
-   The app must function completely without the classifier.

A future opt-in online recognition service would materially change the
privacy proposition and must be treated as a separate product decision,
privacy review, and consent flow --- not an implementation shortcut.

------------------------------------------------------------------------

## 11. Proposed application structure

``` text
OVMEquipment/
├── App/
│   └── OVMEquipmentApp.swift
├── Models/
│   ├── EquipmentItem.swift
│   ├── Cylinder.swift
│   ├── RegulatorSet.swift
│   ├── RegulatorComponent.swift
│   ├── MaintenanceEvent.swift
│   └── NotificationPreference.swift
├── Services/
│   ├── MaintenanceService.swift
│   ├── NotificationService.swift
│   ├── ImageStore.swift
│   ├── OCRService.swift
│   ├── SerialNumberCandidateService.swift
│   └── BrandRecognitionService.swift
├── ViewModels/
│   ├── InventoryViewModel.swift
│   ├── EquipmentEditorViewModel.swift
│   └── MaintenanceViewModel.swift
├── Views/
│   ├── Inventory/
│   ├── EquipmentDetail/
│   ├── EquipmentEditor/
│   ├── Maintenance/
│   ├── Scanner/
│   └── Settings/
├── Utils/
│   ├── OVMTheme.swift
│   └── SharedComponents.swift
├── Assets.xcassets/
├── PrivacyInfo.xcprivacy
└── Info.plist

OVMEquipmentTests/
├── MaintenanceServiceTests.swift
├── NotificationServiceTests.swift
├── SerialNumberCandidateServiceTests.swift
├── PersistenceTests.swift
└── ImageStoreTests.swift
```

Keep services protocol-driven where doing so makes camera, OCR,
notification, and persistence behavior testable. Avoid adding
abstraction layers with no concrete testing or substitution benefit.

------------------------------------------------------------------------

## 12. UX / navigation

Recommended tab structure:

``` text
Inventory
Maintenance
Settings
```

### Inventory

Top-level screen:

``` text
OVM Equipment

[ Search equipment ]

All   Cylinders   Regulators

┌────────────────────────────┐
│ [photo] Twinset            │
│          2 × 12 L Steel    │
│          VIP: OK           │
│          Hydro: 42 days    │
└────────────────────────────┘

┌────────────────────────────┐
│ [photo] Primary regulators │
│          Apeks             │
│          Service due       │
└────────────────────────────┘

                         [+]
```

Support:

-   search by name, manufacturer, model, and serial number;
-   filter by type;
-   filter by maintenance status;
-   add item;
-   edit item;
-   delete with confirmation.

### Maintenance

Prioritize attention:

``` text
Needs attention
- Primary regulators — Service due
- Stage 7L — Hydro in 12 days

Upcoming
- Twinset — VIP in 54 days

Current
- 3 items
```

Sort due/expired first, then nearest future date.

### Detail

Show:

-   photo;
-   identity;
-   equipment-specific fields;
-   maintenance timeline;
-   notes;
-   edit action.

### Add flow

First screen:

``` text
Add Equipment

Cylinder
Regulator
```

Then show a type-specific editor.

Do not show future unsupported equipment categories as selectable dead
ends.

------------------------------------------------------------------------

## 13. Visual design rules

Codex must inspect the current OVM Dive Planner source before
implementing UI and use the current repository as source of truth.

### Required consistency

-   dark navy background;
-   cyan OVM accent;
-   dark blue cards;
-   subtle blue borders;
-   light gray-blue primary text;
-   subdued secondary text;
-   red/pink danger state;
-   rounded card treatment consistent with the planner;
-   SF Symbols unless an OVM-owned asset already exists;
-   existing OVM app icon/logo visual language.

### Maintenance colors

Do not overload the main cyan accent.

Suggested semantic presentation:

``` text
OK              checkmark + calm/positive semantic treatment
Approaching     warning triangle + amber/yellow semantic treatment
Due / Expired   exclamation + OVM danger color
Unknown         neutral secondary text
```

Color must not be the only status indicator. Always pair it with
iconography and text for accessibility.

------------------------------------------------------------------------

## 14. Privacy and security guardrails

These rules are non-negotiable for MVP.

``` text
NO account
NO login
NO cloud database
NO OVM backend
NO telemetry SDK
NO ad SDK
NO third-party analytics
NO remote OCR
NO remote image recognition
NO equipment-photo upload
NO serial-number upload
NO background network synchronization
NO automatic manufacturer persistence without confirmation
```

If a dependency introduces network communication, Codex must stop and
document why it is needed before adding it.

The app's privacy manifest and App Store privacy declarations must
reflect actual implementation.

Camera permission text should explain that the camera is used to
photograph equipment and scan identifying text such as serial numbers.

Photo-library permission should be limited to the access mode actually
required by the implementation.

------------------------------------------------------------------------

## 15. Data portability

Local-only must not mean data hostage.

Include in the architecture from the start, even if UI ships after MVP:

``` text
Export inventory
Import inventory
```

Recommended future format:

``` text
OVM Equipment Backup (.ovmequipment)
```

Conceptually a package containing:

``` text
manifest.json
equipment.json
images/
```

Export/import must be explicit user actions through the iOS
share/document picker. Do not create automatic cloud backup logic inside
the app.

If iOS device backup behavior can include the app container, document
that honestly; do not market "local-only" as "physically impossible for
an OS backup to copy."

------------------------------------------------------------------------

## 16. MVP scope

### MVP --- must build

-   OVM-branded SwiftUI shell;
-   local persistence;
-   cylinder CRUD;
-   regulator-set/component CRUD;
-   equipment photo;
-   manual serial-number entry;
-   camera serial-number OCR;
-   mandatory OCR confirmation;
-   deterministic maintenance status;
-   maintenance dashboard;
-   configurable reminder lead times;
-   local notifications;
-   search/filter;
-   delete/replace image cleanup;
-   unit tests;
-   privacy manifest / permission descriptions;
-   README and architecture notes.

### Phase 1.1

-   explicit local export/import;
-   maintenance history rather than only latest/next dates;
-   multiple equipment photos;
-   richer regulator component handling;
-   accessibility/UI polish;
-   localization.

### Phase 2

-   OCR-based manufacturer suggestions;
-   optional bundled Core ML brand classifier;
-   CCR;
-   BCD/wing;
-   drysuit;
-   DPV;
-   dive computer;
-   lights;
-   other serviceable equipment.

------------------------------------------------------------------------

## 17. Acceptance criteria

The MVP is complete only when all of the following are true:

-   App can be used in airplane mode after installation.
-   Creating, editing, viewing, and deleting equipment requires no
    network.
-   Cylinder and regulator data survives app restart.
-   Equipment photos survive app restart and are deleted when the owning
    record is deleted.
-   A serial number can be typed manually.
-   A serial number can be scanned from the camera.
-   OCR text is never persisted to `serialNumber` until user
    confirmation.
-   OCR failure has a manual-entry path.
-   VIP, hydro, and regulator service statuses are deterministic and
    tested.
-   Due dates can generate local notifications at configured lead times.
-   Editing a due date replaces stale pending notifications.
-   Deleting an item removes its pending notifications.
-   Maintenance screen orders overdue/due items ahead of future items.
-   No equipment data is sent over the network.
-   UI follows OVM Dive Planner theme and asset language.
-   Status is understandable without relying on color alone.
-   Tests cover date boundaries including today, tomorrow, lead-time
    boundary, leap-year/calendar behavior where relevant.
-   Camera/notification permission denial does not break manual
    inventory use.
-   App has no dependency on OVM Dive Planner's decompression engines.

------------------------------------------------------------------------

## 18. Testing strategy

### Unit tests

Test:

-   maintenance status calculation;
-   due-date boundary behavior;
-   reminder-date generation;
-   notification identifier stability;
-   serial candidate normalization;
-   serial candidate scoring;
-   regulator set/component relationships;
-   model validation;
-   image filename/path management.

### Persistence tests

Test:

-   create/read/update/delete cylinder;
-   create/read/update/delete regulator set;
-   cascade or explicit deletion behavior;
-   image cleanup;
-   migrations when schema versioning is introduced.

### UI tests

At minimum:

-   add cylinder manually;
-   add regulator;
-   scan serial -\> confirmation screen;
-   cancel scan -\> no serial persisted;
-   deny camera -\> manual entry still works;
-   enable reminders -\> permission path;
-   delete equipment.

### OCR fixtures

Keep a small test fixture set of synthetic or legally owned
equipment-label images containing:

-   clear serial;
-   low contrast;
-   engraved text;
-   multiple numbers;
-   `S/N` label;
-   ambiguous `O/0`;
-   rotated label.

Never tune OCR logic to one manufacturer.

------------------------------------------------------------------------

## 19. Codex working guardrails

Create a repository-level `AGENTS.md` or equivalent Codex instruction
file containing these rules.

``` markdown
# OVM Equipment Codex Rules

## Repository boundary
The writable repository is `data-project2/OVMEquipment`.
The canonical local root is `/Users/ferryouwerkerk/Documents/OVMEquipment`.
`data-project2/OVMDivePlanner` is read-only reference material.
Never add Equipment code to, commit to, branch from, or modify OVMDivePlanner
during an Equipment task.

## Product boundary
This is a privacy-first local equipment manager.
Do not add accounts, cloud sync, analytics, remote APIs, or server dependencies.

## Reference app
Before visual/UI work, inspect the current `data-project2/OVMDivePlanner`
reference source or the supplied local reference checkout.
Reuse its OVM visual language; do not invent a second OVM design system.

## Safety wording
Maintenance dates are administrative reminders.
Never label equipment "safe to dive" based on stored dates.

## Persistence
All equipment data is local.
Never persist an OCR serial number until the user explicitly confirms it.

## Camera/OCR
OCR and image analysis must run on device for MVP.
Manual entry must always remain available.

## Brand recognition
Brand recognition is optional and must be user-confirmed.
Do not call remote vision/AI APIs.

## Architecture
Business rules belong in services/models, not SwiftUI views.
Date/status and reminder calculations must be deterministic and unit tested.

## Scope
Do not implement CCR, BCD/wing, drysuit, DPV, computer, light, or other
future categories unless explicitly requested.

## Dependencies
Prefer Apple frameworks.
Before adding any third-party dependency, explain why the Apple SDK is insufficient.

## Git
Make small, reviewable commits.
Do not rewrite history.
Do not change unrelated files.
Do not claim tests passed unless they were actually executed.

## Completion
At the end of each task report:
1. files changed;
2. behavior implemented;
3. tests added/run;
4. remaining limitations;
5. privacy impact, if any.
```

------------------------------------------------------------------------

## 20. Recommended Codex implementation sequence

### Prompt 0 — repository bootstrap and reconnaissance

```text
We are building a new native iOS app named OVM Equipment in its own repository.

Writable implementation repository:
- GitHub: data-project2/OVMEquipment
- local root: /Users/ferryouwerkerk/Documents/OVMEquipment

Read-only visual/reference repository:
- GitHub: data-project2/OVMDivePlanner
- local reference root when available:
  /Users/ferryouwerkerk/Documents/OVMDivePlanner

First verify that you are operating in the OVMEquipment repository. If the
repository does not yet exist locally, report that before making changes.
Never create Equipment source inside OVMDivePlanner.

Then inspect OVM Dive Planner READ-ONLY and identify:
- Swift/iOS/Xcode project conventions;
- OVMTheme and reusable visual components;
- app icon/logo assets;
- navigation conventions;
- persistence conventions if any;
- privacy manifest conventions;
- test structure;
- Codex/project instruction files.

Produce:
1. repository-boundary confirmation;
2. reconnaissance summary;
3. exact OVM Equipment project structure;
4. visual tokens/assets to reproduce or reuse;
5. proposed minimum iOS target and persistence choice;
6. decisions requiring user approval.

Guardrails:
- Do not modify OVMDivePlanner.
- Do not create branches, commits, or PRs in OVMDivePlanner.
- Do not copy dive-planning/decompression engines.
- Do not invent colors when an OVM source value exists.
- Do not create a shared package yet.
- Do not begin feature implementation until reconnaissance is complete.
```

### Prompt 1 --- scaffold

``` text
In the `data-project2/OVMEquipment` repository only, create the OVM Equipment
native SwiftUI application scaffold using the approved architecture.

Implement:
- app entry point;
- OVM theme copied from the current reference values;
- Inventory / Maintenance / Settings tab navigation;
- empty-state screens;
- asset catalog structure;
- privacy manifest;
- test target.

Do not implement persistence or equipment forms yet.

Keep the app buildable at the end of this step. Run the build/tests available
in the environment and report exact results.
```

### Prompt 2 --- persistence and models

``` text
Implement the local equipment domain model and persistence.

MVP types:
- Cylinder
- RegulatorSet
- RegulatorComponent
- MaintenanceEvent
- notification preferences where appropriate

Use SwiftData if the agreed deployment target supports the selected design.
If it does not, stop and propose the Core Data equivalent before changing
architecture.

Add model/persistence tests.

Guardrails:
- local storage only;
- no networking;
- no CloudKit;
- no account model;
- no future equipment categories beyond enum/schema extensibility.
```

### Prompt 3 --- cylinder workflow

``` text
Implement complete Cylinder CRUD.

Fields:
name, manufacturer, cylinder type, material, volume, working pressure,
serial number, manufacture date, VIP date, next VIP due date,
hydrostatic-test date, next hydro due date, notes.

Use OVM visual components and theme.
Support validation without inventing jurisdiction-specific inspection rules.

Add unit/UI tests for create, edit, persistence, and delete.
```

### Prompt 4 --- regulator workflow

``` text
Implement complete Regulator CRUD using RegulatorSet and RegulatorComponent.

Support:
- first stage;
- primary second stage;
- alternate second stage;
- optional additional second stage;
- manufacturer/model/serial at component level;
- service dates and service interval;
- notes.

The UI should make a regulator set feel coherent while preserving component
serial numbers and service data.

Add tests for component relationships and deletion behavior.
```

### Prompt 5 --- maintenance engine and dashboard

``` text
Implement a deterministic MaintenanceService and the Maintenance tab.

Statuses:
- unknown;
- ok;
- approaching;
- due.

Events:
- cylinder VIP;
- cylinder hydro;
- regulator service.

The UI must show the most urgent item status and list individual maintenance
events in detail.

Never use the word "safe" as a derived maintenance state.

Add boundary-date tests before wiring status into the UI.
```

### Prompt 6 --- local notifications

``` text
Implement configurable local maintenance reminders with UserNotifications.

Lead-time presets:
90, 60, 30, 14 days, plus custom.

Requirements:
- permission requested contextually;
- notification IDs deterministic;
- editing dates/preferences replaces stale notifications;
- deleting equipment removes its notifications;
- past reminder dates are not scheduled;
- no server or push notification service.

Abstract notification scheduling sufficiently to unit test reminder generation.
```

### Prompt 7 --- equipment photos

``` text
Add a primary equipment photo.

Support:
- camera capture;
- photo library selection;
- replace;
- remove.

Store managed images locally under Application Support using equipment IDs.
Resize/compress sensibly and remove managed image files when equipment is
deleted.

Do not upload images or introduce third-party image services.
Handle permission denial without blocking manual equipment entry.
```

### Prompt 8 --- serial-number OCR

``` text
Implement on-device serial-number scanning.

Use Apple Vision text recognition.
Create OCRService and SerialNumberCandidateService separately from the UI.

Flow:
camera -> OCR -> candidate ranking -> confirmation/edit screen ->
explicit "Use Serial Number" -> persistence.

Requirements:
- never auto-save OCR output;
- preserve ambiguous characters for user confirmation;
- manual entry always available;
- failure provides Try Again / Enter Manually / Cancel;
- no remote OCR/API.

Add unit tests for candidate normalization/scoring and UI coverage for
confirmation/cancellation.
```

### Prompt 9 --- search, filters, polish

``` text
Implement inventory search and filters.

Search:
- name;
- manufacturer;
- model;
- serial number.

Filters:
- all;
- cylinders;
- regulators;
- maintenance status.

Polish the UI against the OVM Dive Planner reference:
spacing, cards, typography, accent use, empty states, icons, accessibility,
Dynamic Type, VoiceOver labels, and status communication that does not rely
only on color.
```

### Prompt 10 --- privacy audit

``` text
Perform a privacy and offline architecture audit of OVM Equipment.

Verify:
- no account/login;
- no cloud persistence;
- no CloudKit;
- no analytics;
- no telemetry;
- no ad SDK;
- no remote OCR;
- no remote image recognition;
- no equipment or serial-number network transfer;
- permission descriptions are accurate;
- privacy manifest matches implementation.

Search the project for networking APIs and third-party dependencies.
Document every finding.

Do not weaken the privacy requirement to resolve implementation convenience.
```

### Prompt 11 --- MVP release review

``` text
Review the full MVP against OVM_EQUIPMENT_BUILD_PLAN.md.

Run all available builds and tests.

Produce a gap report grouped into:
- blocker;
- required before TestFlight;
- optional polish;
- Phase 1.1;
- Phase 2.

Do not implement new Phase 2 features during this review.
Fix only clear MVP defects after listing them.
```

### Prompt 12 --- brand recognition spike

``` text
Do not modify production behavior yet.

Create a technical spike for offline manufacturer recognition.

Evaluate:
1. OCR word matching against a bundled manufacturer alias catalog;
2. optional on-device Core ML image classification.

Measure:
- expected implementation complexity;
- app-size impact;
- privacy impact;
- testability;
- false-positive risk;
- user-confirmation UX.

Recommendation must preserve these constraints:
- fully offline;
- no remote AI/vision APIs;
- prediction is a suggestion only;
- no auto-save;
- low-confidence result means no suggestion;
- app works without brand recognition.

Implement only the OCR alias matcher prototype unless explicitly instructed
to proceed with a Core ML model.
```

------------------------------------------------------------------------

## 21. Codex Definition of Done for every implementation prompt

Before Codex declares a step complete it must:

1.  inspect the relevant existing code first;
2.  state assumptions;
3.  keep changes within requested scope;
4.  compile the app if the environment permits;
5.  run relevant tests;
6.  add tests for new deterministic logic;
7.  report any test/build failure rather than hiding it;
8.  check for accidental network/cloud behavior;
9.  update documentation when architecture or user-visible behavior
    changes;
10. leave the repository in a reviewable state.

------------------------------------------------------------------------

## 22. Architecture decision records to create

Codex should create short ADRs as implementation begins:

``` text
ADR-000 Separate product repository
ADR-001 Local-only persistence
ADR-002 Equipment domain model
ADR-003 Maintenance status semantics
ADR-004 Local notification scheduling
ADR-005 Local image storage
ADR-006 On-device serial-number OCR
ADR-007 Offline manufacturer recognition (Phase 2)
```

Each ADR should contain:

``` text
Context
Decision
Alternatives considered
Consequences
Privacy impact
```

------------------------------------------------------------------------

## 23. Product decisions to keep explicit

The following should not be silently decided by Codex:

1.  Minimum iOS version: match OVM Dive Planner iOS 16 or move the new
    app to iOS 17+ for SwiftData.
2.  Final app name: OVM Equipment vs OVM Gear vs OVM Equipment Manager.
3.  Final bundle identifier and signing configuration.
4.  Whether inspection/service intervals are manually entered only or
    selected from configurable presets.
5.  Whether maintenance history is MVP or Phase 1.1.
6.  Whether local export/import ships in MVP or immediately after.
7.  Whether brand recognition stops at OCR alias matching or later adds
    Core ML.

Until changed, this plan assumes the product name **OVM Equipment**,
local-only MVP, and brand recognition as Phase 2.

------------------------------------------------------------------------

## 24. Recommended first execution

Give Codex **Prompt 0** first. Do not ask it to build the entire
application in one prompt.

After reconnaissance, resolve the minimum-iOS / SwiftData decision. Then
execute Prompts 1--11 sequentially, requiring a build/test checkpoint
after each material slice.

This keeps the implementation auditable, prevents Codex from drifting
into cloud services or unrelated dive-planner code, and makes the
privacy proposition an architectural constraint rather than a marketing
statement.
