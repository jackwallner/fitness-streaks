# FitnessStreaks Pro — Paywall Design Spec

> **Current issue:** The paywall is too tall. The content below is the existing design — it needs to be condensed for smaller screens or better scroll behavior. Use this as reference for Figma/RevenueCat alternatives.

---

## Visual Style

| Property | Value |
|---|---|
| **Vibe** | Retro pixel arcade, neon-on-dark |
| **Font** | JetBrainsMono (Bold for headings, Regular for body) |
| **Corners** | Sharp (0 radius) — "pixel panel" aesthetic |
| **Borders** | 2px solid stroke on every panel |
| **Glow** | Colored shadow on icons and flame |

### Color Palette (Dark Mode — primary)

| Token | Hex | Usage |
|---|---|---|
| `retroBg` | `#0a0612` | Screen background |
| `retroBgRaised` | `#120a22` | Card/panel fill |
| `retroBgCard` | `#1e1236` | Alternate card fill (context banner) |
| `retroInk` | `#f4ecff` | Primary text |
| `retroInkDim` | `#a395c0` | Secondary text |
| `retroInkFaint` | `#4a3d6b` | Borders, tertiary |
| `retroMagenta` | `#ff2d95` | Pro accent, selected state |
| `retroLime` | `#c8ff00` | Purchase CTA, feature icon |
| `retroCyan` | `#2dd4ff` | Feature icon, restore link, terms link |
| `retroAmber` | `#ffb020` | Feature icon, status messages |

---

## Layout (top → bottom)

### 1. Navigation Bar

```
  ┌──────────────────────────────────┐
  │  FITNESSSTREAKS PRO        CLOSE │
  └──────────────────────────────────┘
```
- Title: JetBrainsMono Bold, 11pt, tracking 2, magenta
- "CLOSE": JetBrainsMono Bold, 10pt, dim ink — dismisses sheet

---

### 2. Context Banner *(conditional — shown from broken streak / limit upsell)*

```
  ┌──────────────────────────────────────────────┐
  │ !  Save your 45-day streak… unlock Pro to    │
  │    spend a Grace Day.                        │
  └──────────────────────────────────────────────┘
```
- "!": JetBrainsMono Bold 14pt, amber, left-aligned
- Body: JetBrainsMono Regular 11pt
- Panel: 12px padding, amber border (#ffb020, 2px), `retroBgRaised` fill

---

### 3. Hero Block

```
  ┌──────────────────────────────────────────────┐
  │  🔥                                   [PRO]  │
  │                                              │
  │  PROACTIVE ALERTS THAT                       │
  │  PROTECT YOUR STREAKS.                       │
  │                                              │
  │  Pro watches for streaks that are            │
  │  slipping, sends at-risk reminders,          │
  │  and spends banked Grace Days                │
  │  automatically when life still gets          │
  │  in the way.                                 │
  └──────────────────────────────────────────────┘
```
- **Flame icon**: 56×56 pixel-art fire sprite (16×16 grid, Canvas-drawn), magenta glow shadow
- **[PRO] chip**: JetBrainsMono Bold 9pt, white text on magenta fill, 6px h-padding, 4px v-padding
- **Headline**: JetBrainsMono Bold 14pt, `retroInk`, line spacing 4
- **Body**: JetBrainsMono Regular 11pt, `retroInkDim`, line spacing 3
- Panel: 16px padding, magenta border (#ff2d95, 2px), `retroBgRaised` fill

---

### 4. Feature List (3 rows)

```
  ┌──────────────────────────────────────────────┐
  │ 🔔  PROACTIVE STREAK ALERTS                  │
  │     Get a daily at-risk nudge for your       │
  │     most urgent active streak before the     │
  │     goal slips away.                         │
  ├──────────────────────────────────────────────┤
  │ 🛡️  AUTOMATIC GRACE SAVES                   │
  │     Miss anyway? Pro spends a banked         │
  │     Grace Day to preserve the streak —       │
  │     no panic, no manual recovery.            │
  ├──────────────────────────────────────────────┤
  │ 📅  EARN GRACE DAYS                          │
  │     1 Grace Day banked for every 30          │
  │     days of streak. Up to 9 saved at once.   │
  └──────────────────────────────────────────────┘
```
- **Icons**: SF Symbols — `bell.badge.fill` (lime), `shield.lefthalf.filled` (cyan), `calendar.badge.plus` (amber), 16pt semibold with colored glow shadow (opacity 0.6, radius 4), fixed 24px width
- **Title**: JetBrainsMono Bold 10pt, `retroInk`, tracking 1
- **Detail**: JetBrainsMono Regular 10pt, `retroInkDim`, line spacing 2
- Panel: 14px padding, `retroInkFaint` border, `retroBgRaised` fill (each row is its own panel)

---

### 5. Product Cards (3 tiers)

```
  ┌──────────────────────────────────────────────┐
  │ YEARLY                    [7 DAYS FREE]      │
  │ Billed yearly · $X.XX/mo                     │
  │                              $XX.XX / yr     │
  └──────────────────────────────────────────────┘
  ┌──────────────────────────────────────────────┐
  │ MONTHLY                                      │
  │ Billed monthly · Cancel anytime              │
  │                              $X.XX / mo      │
  └──────────────────────────────────────────────┘
  ┌──────────────────────────────────────────────┐
  │ LIFETIME                 [BEST VALUE]        │
  │ One-time purchase · Forever yours            │
  │                                 $XX.XX       │
  └──────────────────────────────────────────────┘
```
- **Product name**: JetBrainsMono Bold 11pt, `retroInk`, tracking 1
- **Detail line**: JetBrainsMono Regular 10pt, `retroInkDim`
- **Price**: JetBrainsMono Bold 14pt, magenta when selected, `retroInk` otherwise
- **Badges** ("7 DAYS FREE", "MOST POPULAR", "BEST VALUE"): PixelChip — JetBrainsMono Bold 9pt, white text on accent fill, 6×4px padding
  - Yearly badge: magenta
  - Monthly: no badge
  - Lifetime: lime (#c8ff00)
- **Selected card**: magenta border vs `retroInkFaint` border
- Panel: 14px padding, 2px border, `retroBgRaised` fill
- Tapping a card selects that product

### Loading State
- Centered spinner + "LOADING PRICES…" in dim ink, JetBrainsMono Bold 10pt

### Error State
- "PRICES DIDN'T LOAD" header (JetBrainsMono Bold 10pt, amber)
- Error message body (JetBrainsMono Regular 10pt, dim)
- "TRY AGAIN" (lime) + "NOT NOW" (dim) buttons, plain style

---

### 6. Purchase Button

```
  ┌──────────────────────────────────────────────┐
  │          START 7-DAY FREE TRIAL              │
  └──────────────────────────────────────────────┘
              RESTORE PURCHASES
```
- **Button**: Full-width, JetBrainsMono Bold 12pt, dark text on lime (#c8ff00) fill, 2px lime border, inner 2px white 25% opacity border inset
- Press state: 1px offset (down-right)
- **Processing state**: same button but "PROCESSING…"
- **Restore link**: JetBrainsMono Bold 10pt, cyan, tracking 1, plain button style

---

### 7. Status Message (conditional)

- JetBrainsMono Regular 10pt, amber, centered
- Shows: "WELCOME TO PRO.", "PURCHASE PENDING APPROVAL.", "PRO RESTORED.", "NO ACTIVE PURCHASES FOUND.", error messages

---

### 8. Legal Block

```
  FitnessStreaks Pro auto-renews at $X.XX per
  year (yearly) or $X.XX per month (monthly).
  Free trials convert to a paid yearly
  subscription if not cancelled at least 24
  hours before they end. Payment is charged to
  your Apple ID at confirmation of purchase.
  Manage or cancel anytime in iOS Settings →
  Apple ID → Subscriptions.

  Lifetime is a one-time purchase that never
  renews.

  TERMS OF USE (EULA)    PRIVACY
```
- Body: JetBrainsMono Regular 10pt, `retroInkDim`, line spacing 2
- Links: JetBrainsMono Bold 10pt, cyan, tracking 1
  - Terms: `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
  - Privacy: `https://jackwallner.github.io/fitness-streaks/privacy-policy.html`

---

## Product IDs (StoreKit)

| Tier | ID |
|---|---|
| Yearly | `com.jackwallner.streaks.yearly` |
| Monthly | `com.jackwallner.streaks.monthly` |
| Lifetime | `com.jackwallner.streaks.lifetime` |

**Free trial**: Yearly only — 7 days (P1D, 7 periods). Trial text: "7 DAYS FREE"

---

## Overall Dimensions

| Element | Approx. height |
|---|---|
| Nav bar | 44pt |
| Context banner (optional) | ~60pt |
| Hero block | ~180pt |
| Feature list (3 rows) | ~255pt |
| Product cards (3) | ~300pt |
| Purchase button + restore | ~70pt |
| Legal block | ~200pt |
| **Total** | **~1100pt** (requires scroll on most devices) |
