# Phase 3 – Drag / Grid Results

## Summary
Implemented **Candidate A** (`NSWindow.performDrag(with:)`) as the drag mechanism.
Candidate B (custom `mouseDown`/`mouseDragged`/`mouseUp`) was not needed because Candidate A works smoothly with public API.

## Changes
| File | Change |
|------|--------|
| `RoundedHostingView` | `mouseDown` → on `.leftMouseDown` calls `window?.performDrag(with: event)`; posts `.pulsePaneWindowDragEnded` notification after drag returns. |
| `WindowController` | `isMovableByWindowBackground = false` (built-in background drag disabled).<br>Observes `.pulsePaneWindowDragEnded` → snaps frame to safe-area edges via `DesktopGeometry.snapToEdges` and persists.<br>`windowDidMove` now only persists frame (no continuous snap). |

## Behavior
- **Drag start**: left-click anywhere on widget background → window follows pointer smoothly.
- **During drag**: system handles pointer tracking; widget stays within screen bounds (macOS constrains window drag).
- **On release**: notification fires → frame snapped to nearest safe-area edge (16 pt aesthetic margin, 20 pt snap threshold) and persisted.
- **Right-click**: passes to `super` → context menu appears (unchanged).
- **Other moves** (Dock change, display hot‑plug): `windowDidMove` persists frame; `handleScreenParametersChange` recovers if off-screen.

## Safe Movement Region (Phase 3B)
- Uses `DesktopGeometry.safeArea(for:)` → `visibleFrame` inset by `aestheticMargin` (16 pt).
- `snapToEdges` clamps origin to `[safeArea.minX, safeArea.maxX‑width]` and `[safeArea.minY, safeArea.maxY‑height]`.
- No aggressive magnetic snapping during drag; only on release.

## Snap / Grid Experiment (Phase 3C)
- **Current**: edge‑snap only (safe-area edges). Configurable via `DesktopGeometry.snapThreshold` and `aestheticMargin`.
- **Grid snap**: not enabled. The ~180 pt / 8 pt / 180 pt hypothesis remains a **WORKING HYPOTHESIS**; constants are isolated in `DesktopGeometry` and can be toggled later without codebase‑wide changes.

## Window Footprint (Phase 3D)
- PulsePane size: **340 × 430 pt** (fixed by content). Not forced into a 1×1 native cell.
- Snap calculations preserve actual widget size; origin is aligned to candidate positions.

## Persistence
- Final frame persisted via `persistFrame()` (versioned `v2|{x,y,w,h}`).
- On launch: `restoredFrame()` validates against current screens; off‑screen → `recoverFrame()` → default centered.
- Dock / display changes: `handleScreenParametersChange` re‑validates and recovers.

## Tests
- All existing 153 unit tests pass.
- Pure geometry tests cover `DesktopGeometry` (safe area, clamp, snap, recovery).
- No UI‑automation tests for pointer interaction (not required per scope).

## Decision
**Candidate A accepted** – simplest public‑API solution, smooth, no custom event loop, respects safe area, snaps on release.

**Candidate B rejected** – not prototyped because Candidate A meets all criteria.

## Remaining UNKNOWN / PARTIAL
- Exact Dock‑position / auto‑hide transition behavior for drag (not exercised).
- Display scaling / multi‑display drag constraints (hardware pending).
- Grid‑snap parameters (hypothesis only).

---

*Phase 3 review gate reached. Awaiting approval before Phase 4 (Network/UI bugs, accessibility polish).*