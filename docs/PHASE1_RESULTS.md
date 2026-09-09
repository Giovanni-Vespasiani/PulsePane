# Phase 1 – Window Behavior Lab Results

## Summary
- **WL‑001** (window level): Compared level +1 (v2.4) vs +2 (native widget layer).  
- **CB‑001** (collectionBehavior): Tested Variant A (5‑flag) vs Variant B (minus `.transient`) at level +2.

## Evidence
| Config | Measured (logs) | Observed (manual) |
|--------|----------------|-------------------|
| Native widget layer (`Centro Notifiche`) | **MEASURED** – layer `-2147483601` in all CGWindowList views | — |
| PulsePane entries in CGWindowList | **MEASURED** – zero at both levels (known limitation) | — |
| Show Desktop (F11) | — | **OBSERVED** – Level +2 + Variant B: widget visible then slow “depth” recession |
| Mission Control (Ctrl+Up) | — | **OBSERVED** – disappears (hidden) |
| Fullscreen app | — | **OBSERVED** – PulsePane stays below fullscreen content |
| Z‑order vs native widgets | — | **OBSERVED** – PulsePane below native widgets |
| Z‑order vs Finder desktop icons | — | **OBSERVED** – PulsePane above Finder icons |

## Inferences
- Level +2 matches the measured native‑widget layer (`-2147483601`).
- Variant B (without `.transient`) keeps Mission Control hidden, preserves fullscreen‑below behavior, retains Spaces/Cmd‑Tab guarantees.
- Show Desktop still shows a slow recession → **not native‑equivalent**; further public‑API improvement UNKNOWN.

## Decision (Phase‑1 gate)
Adopt **provisional defaults**:
- **Window level**: `kCGDesktopIconWindowLevel + 2` (`-2147483601`)
- **collectionBehavior**: `[.stationary, .canJoinAllSpaces, .ignoresCycle, .fullScreenNone]` (Variant B)

These become the new defaults in `WindowController`. Rollback to v2.4 settings remains possible via `MP_WINDOW_LEVEL` / `MP_BEHAVIOR` env vars.

## Remaining UNKNOWN
- Exact `excludeDesktopElements` classification for PulsePane at +2 (cannot be measured via CGWindowList).
- Whether public‑API tweaks can eliminate the Show Desktop recession.
- Fullscreen transition animation details.
- Wallpaper click, Finder click, Space switch, Cmd‑Tab (covered by static flags).

---
*Phase 1 gate passed – proceeding to Phase 2.*