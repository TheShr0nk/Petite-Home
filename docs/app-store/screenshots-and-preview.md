# Screenshots and app preview — capture plan

Do this once the app builds and runs in the simulator. Total time ≈ 45 minutes: 15 to seed data, 10 to capture, 20 to frame.

## 1. Seed the simulator (one household, realistic data)

Use a fictional family so nothing real ships: **Casey & Ryan**, kids **June (3)** and **Theo (8 mo)**, pediatrician Dr. Alvarez, allergy "peanuts" on June, Theo on no meds, insurance card captured, two emergency contacts (grandma, a neighbor), two sitters, a date night Saturday with sitter "Asked", a passport expiring in 40 days, a vault with a birth certificate and SSN card, three tasks, this week's dinners planned.

Unlock premium with a Founding 500 code (`FoundingCode.make(body:)` in a test, or the "Unlock while we're testing" button if the RevenueCat key is empty) so every premium screen is populated.

## 2. Capture

Two simulators, light mode, 9:41 status bar:

```bash
# 6.9" — required
xcrun simctl boot "iPhone 17 Pro Max"
xcrun simctl status_bar "iPhone 17 Pro Max" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
# 6.5" — required (older frame)
xcrun simctl boot "iPhone 11 Pro Max"
xcrun simctl status_bar "iPhone 11 Pro Max" override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

# capture (⌘S in Simulator also works)
xcrun simctl io booted screenshot ~/Desktop/shots/01-home.png
```

Required sizes: 6.9" = 1320×2868, 6.5" = 1284×2778 (Apple accepts 1242×2688 too). Capture the eight below on both.

| # | File | Screen | State |
|---|------|--------|-------|
| 1 | 01-home | Home tab | Ring at ~85%, "Tonight" showing dinner, share buttons visible |
| 2 | 02-hook | Onboarding screen 1 | All four lines revealed, button visible |
| 3 | 03-child | June's child card | Doctor, allergy, medications, routine filled |
| 4 | 04-cardscan | Insurance card scan | Camera sheet with card detected (or the filled insurance section if the sim camera is blank) |
| 5 | 05-share | Trusted sharing sheet | Guardian selected, Standing on |
| 6 | 06-expiry | Expirations list | Passport in 40 days, car seat in 6 months |
| 7 | 07-vault | Vault | Face ID prompt dismissed, two documents listed |
| 8 | 08-planner | Life Sync week | Both calendars, date night with sitter "Asked", tasks, meals |

Dark-mode variants are optional; skip for 1.0.

## 3. Frame and caption

Fastest path: Figma with a free App Store screenshot template (or Screenshots Pro). Background cream `#FCF8F2`, caption in Fraunces at the top, device frame below, ink `#2F2A26` text. Captions are in `listing-copy.md` → Screenshot captions. Export at the exact pixel sizes above; Apple rejects anything else.

If you'd rather not touch Figma: hand me the eight raw PNGs and I'll composite the framed set with Pillow in the brand tokens.

## 4. App preview video (15–30 s, portrait, 6.9" and 6.5")

Apple's preview rules: must be captured from the app (screen recording), no hands or device mockups, no prices in the video, audio optional. Record in Simulator:

```bash
xcrun simctl io booted recordVideo --codec h264 --mask ignored ~/Desktop/preview-69.mov
# ctrl-C to stop
```

Storyboard (25 s):

| Time | On screen | Caption overlay |
|------|-----------|-----------------|
| 0–4 s | Hook screen, lines reveal one by one | — |
| 4–8 s | Tap "Let's fix that" → household chips → add June | Five minutes, start to finish |
| 8–12 s | June's card: doctor, allergy, meds | Who to call, what they're allergic to |
| 12–15 s | Home ring filling to 85% | — |
| 15–19 s | Share sheet → guardian → standing link → Messages compose | Hand it to grandma in one tap |
| 19–23 s | Vault opens with Face ID, documents listed | Premium keeps the papers you can't lose |
| 23–25 s | Planner week with date night + sitter "Confirmed" | Built for two |
| 25 s | Cream end card: wordmark + "Less to question. More to trust." | — |

Edit in iMovie or CapCut: trim, add the caption overlays (Fraunces, ink on cream), optional soft piano bed. Export H.264, 30 fps, portrait at 886×1920 for 6.9" and 886×1920 (or 1080×1920) for 6.5"; App Store Connect accepts both. Poster frame: the Home screen at 12 s.

Higgsfield / DansUGC are for TikTok, not here — Apple will reject an App Store preview that isn't actual app footage.

## 5. Upload order in App Store Connect

1. Create the app record (bundle ID co.petitehome.app) if not done
2. Subscriptions group + two products + intro offers, then the Paid Apps agreement
3. Paste listing copy, keywords, URLs
4. Upload 6.9" set (preview first, then 8 screenshots), then 6.5"
5. Privacy nutrition labels (see listing-copy.md)
6. Reviewer notes with a Founding 500 code
7. Archive from Xcode → TestFlight → pass to Casey → submit
