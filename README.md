# Petite Home — iOS

The household operating system for families with young kids. Three areas plus
Home: the **Binder** (free; the printable export is still titled "The Family
File", as the website promises), the **Planner** (premium: both calendars,
tasks, meals, and family plans with sitters), and the **Vault** (premium).
Names live in `AppCopy` so a rename is one line.

Brand: Petite Home Co. · "Less to question. More to trust."

## Build

The Xcode project is generated from `project.yml`, so the `.xcodeproj` is not
committed.

```
brew install xcodegen
xcodegen generate
open PetiteHome.xcodeproj
```

Then in Xcode:

1. Set your team under Signing & Capabilities (the spec leaves `DEVELOPMENT_TEAM` empty). The App ID needs iCloud (CloudKit) and In-App Purchase; nothing else.
2. Confirm the iCloud container `iCloud.co.petitehome.app` exists in your developer account, or change it in `PersistenceController.cloudContainerID` and the entitlements file.
3. Fill in `RevenueCatAPIKey` and `PostHogAPIKey` in `PetiteHome/Resources/Info.plist`. Both are public SDK keys. Without the RevenueCat key the paywall shows list prices but cannot purchase; without the PostHog key analytics never start.
4. Run. The scheme uses `Products.storekit` so the paywall works in the simulator.

Requirements: Xcode 15.4+, iOS 17.0+, Swift 5.10. Two dependencies via Swift Package Manager: `posthog-ios` and RevenueCat's `purchases-ios`.

## Where things live

```
PetiteHome/
  App/         entry point, AppState (tabs, paywall gate, deep links), RootView, MainTabView
  Design/      Theme.swift (tokens copied from the website), Typography (Fraunces), components
  Models/      SwiftData models, value types, Completeness scoring
  Services/    persistence, CloudKit sharing, keychain, vault crypto, StoreKit, notifications,
               contacts, Vision card scan, PDF export, analytics, Klaviyo, task templates
  Features/    Onboarding, Home, FamilyFile, Children, LifeSync, Tasks, Vault, Picks, Settings,
               Paywall, Export, Sharing
  Resources/   Info.plist, entitlements, StoreKit config, bundled font, asset catalog
PetiteHomeTests/  completeness, age segments, recurrence, crypto, founding codes, card parsing
```

## Design tokens

`Design/Theme.swift` copies the live site's tokens from
`petite-powder/02-web/src/app/globals.css` (cream, kraft, ink, muted, rule,
radius 14/10) and the powder blue from `00-brand/color/tokens.css`. Where the
site has no token for a role (sand, success, warn, danger) the brief's target
palette is used. Each token is annotated with its source.

The site's display face is Fraunces (loaded from Google Fonts by `next/font`),
so the same variable TTF is bundled under the OFL. Body text is SF Pro.

## Things to know before TestFlight

**Partner sharing on iOS 17.** SwiftData has no CKShare API, so
`CloudSharingService` opens a parallel `NSPersistentCloudKitContainer` over the
same store to create and accept the share. The owner's side is straightforward.
On the partner's device the shared household lands in the `.shared` store,
which SwiftData's `ModelContainer` does not read. This is the single biggest
risk in the ship order and is exactly why the brief gates step 6 on step 5
working across two real devices. If it does not, the fallback is to move the
persistence layer to Core Data + `NSPersistentCloudKitContainer` (the models
are already shaped for it: every attribute has a default, every relationship
is optional). Nothing in the views would change.

**Vault key sharing.** The household's AES key is stored on the Household
record in a field marked `.allowsCloudEncryption`. CloudKit encrypts that
field end to end and hands it to accepted share participants, so a partner on
a different Apple ID opens the vault once the household share works. The
iCloud Keychain keeps a cache for offline use. Gate and alarm codes use a
separate device key that never touches a record.

**Trusted-person links.** These are CloudKit shares with public read-only
permission on a rendered PDF. The recipient needs the app installed to open
the link. The owner's app revokes the share after the expiry date on next
launch.

**Klaviyo.** If the user types an email on the reveal screen, the app posts to the site's existing `/api/subscribe` with
`kind: family-file`, `youngestChildAge` and `placement: ios_app`. The website's
route only accepts a fixed set of placements, so add `ios_app` to `PLACEMENTS`
in `02-web/src/app/api/subscribe/route.ts` or it records as `unknown`.

**Life Sync (premium).** Each phone mirrors its owner's chosen calendars
through EventKit into `CalendarEvent` rows on the household, so the partner
sees them via the household share. Read-only; nothing is written back to the
calendar. Calendar and task choices made during onboarding are held in
`LifeSyncPending` until the trial starts, then applied once. The Tasks tab
lives inside Life Sync as its second segment.

**Meals.** The Meals segment of Life Sync holds a recipe box (free) and the
week's plan (premium). Recipes import from any page carrying schema.org
Recipe JSON-LD (`RecipeImporter`, pure and tested), and share out through the
system share sheet as a branded 1080×1350 card plus the recipe text
(`RecipeShare`). Planned meals appear on the Life Sync agenda and as
"Tonight" on Home; the shopping list is computed from the week's recipes.

**Plans.** `FamilyPlan` covers date nights, outings, trips, appointments and
visitors, with who's going and a sitter state (kids come along / need a
sitter / asked / confirmed). `FreeEveningFinder` proposes evenings with
nothing on either synced calendar, weekends first. `SitterSheet` builds the
text sent to a sitter from the Binder: kids' allergies, meds, notes, who to
call, the address. It never includes codes or account details. The sitter
roster is a value list on the household, so both partners share it.

**Trials without a store (TestFlight).** While `RevenueCatAPIKey` is empty,
"Start free trial" grants premium on that phone for 30 days, stored in the
Keychain, with no purchase. Adding the key switches every trial button to real
RevenueCat purchases; existing local trials run out on their own.

**RevenueCat setup.** In the RevenueCat dashboard create the two App Store
products (`co.petitehome.premium.monthly`, `co.petitehome.premium.annual`, one
subscription group, 7-day introductory free trial on both), an entitlement
called `premium`, and a current offering with a `$rc_annual` and a
`$rc_monthly` package pointing at them. Paste the app's public API key into
Info.plist. For simulator testing, keep `Products.storekit` attached to the
scheme; RevenueCat reads from it in sandbox mode. The app calls `logIn` with the iCloud user record name so purchases follow
the person across their devices.

**Founding 500 codes.** Format `PH-XXXX-XXXX`; the last group is a checksum of
the first (see `FoundingCode`). Issue codes with `FoundingCode.make(body:)`.

**Not verified by a compiler yet.** This codebase was written in an environment
without Xcode. Expect a round of compile fixes on first build; the logic under
test (`PetiteHomeTests`) is pure and should pass as is.

## Motion

`Design/Motion.swift` holds the motion vocabulary, ported from Seek Faith:
0.6s crossfades between onboarding screens, staggered fade-ups within a
screen (`.reveal(n)`), the hook's line-by-line reveal, spring selection on
chips and plan rows, a spring pop on task completion, numeric transitions on
the ring, pulsing dots for anything that takes a moment, and one dark "saved"
moment screen after onboarding. Everything honours Reduce Motion.

## Before TestFlight: Apple platform checklist

- App Store Connect: app record, bundle ID `co.petitehome.app` with iCloud
  (CloudKit), Sign in with Apple and In-App Purchase capabilities; Paid Apps
  agreement signed; the two subscriptions in one group with a 7-day intro offer.
- CloudKit Dashboard: run the app in Development, then **Deploy Schema
  Changes to Production**. Without that, release builds cannot sync. Both the
  SwiftData store and the parallel Core Data stack in `CloudSharingService`
  write to the same schema.
- `CKSharingSupported` is set in Info.plist; without it iOS never delivers
  share acceptances to the app.
- `PrivacyInfo.xcprivacy` declares email, purchase history and anonymous
  analytics. Update it if a new SDK or data type is added. RevenueCat and
  PostHog ship their own manifests.
- There is no sign-in. Identity is the iCloud user record (`CloudIdentity`),
  so there is no account to delete; Settings offers "Delete this household"
  which removes everything from the phone and iCloud.
- App icon: a placeholder (the site's powder-blue mark with a serif P) is in
  `Assets.xcassets/AppIcon`. Replace it with final artwork before release.
- Export compliance: the vault uses CryptoKit AES-GCM, which is standard
  encryption; `ITSAppUsesNonExemptEncryption` is false. Confirm the annual
  self-classification with your counsel if selling outside the US.

## Copy rules

Sentence case. No exclamation points. Never "in case of death". Empty states
say what to do. Every premium lock says "Premium keeps this for you".
