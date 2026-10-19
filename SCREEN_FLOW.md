# Screen flow — Rootiland prototype

All screen artwork was supplied as SVG except the Timeline PNG. The file names below refer to files inside `DesignReferences/`. A separate designer-written instructions file was **not present** in the uploaded ZIP. Navigation and behaviors below are therefore interpreted from the visible mockups and the previous requirements.

| Sketch reference | Built SwiftUI view / behavior |
|---|---|
| `Momentum app icon.svg` | First-launch welcome screen. **Get Started** goes to Onboard 2. |
| `Onboard 2.svg` | Category selection (4 topics). **Next** goes to Onboard 3. |
| `Onboard 3.svg` | Choose an activity in the topic or enter a custom one; **Next** goes to Onboard 4. |
| `Onboard 4.svg` | Choose 30/45/60 minutes; **Next** goes to Onboard 5. |
| `Onboard 5.svg` | Choose every day/week/month; **Next** goes to Onboard 6. |
| `Onboard 6.svg` | Native wheel-style reminder time selection; **Next** goes to Final. |
| `Onboard final.svg` | Habit summary; **Finish Setup** stores the habit and goes to notification choice. |
| `Onboard final notify.svg` | **Allow Notifications** asks iOS permission, **Skip For Now** continues without permission. |
| `Leafy present.svg` | Companion introduction; **Continue** enters the main app. |
| `Homepage track.svg` | **Track** tab: month, dates, completion counts, check-in buttons, + habit. |
| `Homepage topics.svg` | **Topics** tab: 4 clickable category cards, category detail and + habit. |
| `homepage leafy.svg` | **Leafy** tab: native RealityKit island, level/progress and level missions. |
| `homepage timeline.png` | **Timeline** tab: history of completed habits, or an empty state. |
| `homepage settings.svg` | **Settings** tab: notifications, dark mode, system language, units, accent color. |

## Persistent data & functional actions

- Habit creation is available from onboarding and via the `+` toolbar buttons in Track/Topics.
- Check-in buttons update Track, Timeline and Leafy together, with on-device persistence.
- Repeating a check-in in the same day unchecks it; this makes the prototype easy to test.
- A swipe on a habit row can delete it (native destructive action).
- `Settings → Primary Color` changes `#6DD400` / `#E688CB` / `#0088FF`.
- `Settings → Notifications` triggers native permission or removes pending local reminders.
- Tap the Leafy island to open a full-screen viewer with a system glass close button.
- The default iOS Liquid Glass rendering is used for the tab bar and native controls, even where Sketch depicted custom black capsules.

## Awaiting design/asset decisions

1. Final five `.usdz` levels (none were in the ZIP).
2. Art-director-approved icon and character artwork (Sketch exports are screen artboards, not standalone icon assets).
3. Detailed interactions not depicted by the supplied screenshots, especially Track's metrics, Timeline activity and extra topic detail screens.
4. Exact Leafy XP curve and how different habit topics unlock specialized props.
5. End-to-end simulator screenshots and accessibility validation in Xcode on macOS.
