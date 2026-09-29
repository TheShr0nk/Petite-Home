# Petite Home — iOS

The household operating system for families with young kids. Free tier is the
Family File. Premium is the app doing things on its own: recurring tasks,
expiration reminders, an encrypted document vault, trusted-person sharing.

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

1. Set your team under Signing & Capabilities (the spec leaves `DEVELOPMENT_TEAM` empty).
2. Confirm the iCloud container `iCloud.co.petitehome.app` exists in your developer account, or change it in `PersistenceController.cloudContainerID` and the entitlements file.
3. Add `PostHogAPIKey` (and optionally `PostHogHost`) to the Info.plist for analytics. Without a key the SDK never starts.
4. Run. The scheme uses `Products.storekit` so the paywall works in the simulator.

Requirements: Xcode 15.4+, iOS 17.0+, Swift 5.10. One dependency: `posthog-ios` via Swift Package Manager.

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

**Vault key sharing.** The AES key lives in the iCloud Keychain, so it follows
the owner's Apple ID across devices. A partner on a different Apple ID cannot
open vault documents yet; that needs the key wrapped for their account.

**Trusted-person links.** These are CloudKit shares with public read-only
permission on a rendered PDF. The recipient needs the app installed to open
the link. The owner's app revokes the share after the expiry date on next
launch.

**Klaviyo.** The app posts to the site's existing `/api/subscribe` with
`kind: family-file`, `youngestChildAge` and `placement: ios_app`. The website's
route only accepts a fixed set of placements, so add `ios_app` to `PLACEMENTS`
in `02-web/src/app/api/subscribe/route.ts` or it records as `unknown`.

**Life Sync (premium).** Each phone mirrors its owner's chosen calendars
through EventKit into `CalendarEvent` rows on the household, so the partner
sees them via the household share. Read-only; nothing is written back to the
calendar. Calendar and task choices made during onboarding are held in
`LifeSyncPending` until the trial starts, then applied once. The Tasks tab
lives inside Life Sync as its second segment.

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

## Copy rules

Sentence case. No exclamation points. Never "in case of death". Empty states
say what to do. Every premium lock says "Premium keeps this for you".
