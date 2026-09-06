# REBRAND_PLAN.md — MacPerformance v2.1 Rebrand Migration Plan

> This document records the complete identity audit, migration strategy, and
> naming candidates for the MacPerformance → [NEW NAME] rebrand (v2.1).
> **Nothing in this plan is executed until the final name is approved.**

---

## 1. CURRENT IDENTITY INVENTORY

### Core Brand Elements

| Element | Current Value | Type |
|---------|---------------|------|
| **Product Name** | MacPerformance | User-facing product name |
| **Application Display Name** | MacPerformance | CFBundleDisplayName / menu bar / window title |
| **Executable** | MacPerformance | Binary name in MacOS/ |
| **SPM Product** | MacPerformance | `Package.swift` product name |
| **SPM Target** | MacPerformance | `Package.swift` target name |
| **SPM Package Name** | MacPerformance | `Package.swift` package name |
| **Bundle Identifier** | `local.MacPerformance` | CFBundleIdentifier |
| **App Bundle** | `MacPerformance.app` | Bundle directory name |
| **GitHub Repository** | `Giovanni-Vespasiani/MacPerformance` | Remote repo name |
| **GitHub Remote URL** | `git@github-personal:Giovanni-Vespasiani/MacPerformance.git` | SSH remote |

### Persistence & User Data

| Key | Current Value | Purpose |
|-----|---------------|---------|
| **UserDefaults Frame Key** | `MacPerformance.windowFrame` | Window position persistence (versioned as `v2|...`) |
| **Quit Menu Item** | "Quit MacPerformance" | Context menu title |
| **Window Title** | "MacPerformance" | Internal window title (not visible) |

### Documentation References

| File | Occurrences | Notes |
|------|-------------|-------|
| README.md | 1 (title) | Main project title |
| ARCHITECTURE.md | 2 | Header + module reference |
| DECISIONS.md | 1 | Build artifact reference |
| DEVELOPMENT.md | 3 | Header + build paths |
| PROJECT_STATE.md | 6 | Header + multiple references |
| Package.swift | 4 | Package/product/target names |
| scripts/build.sh | 1 | Comment header |
| scripts/make-app.sh | 8 | Paths, Info.plist template, binary name |
| scripts/run.sh | 3 | App paths |
| Sources/MacPerformance/App/MacPerformanceApp.swift | 1 | App struct name |
| Sources/MacPerformance/App/WindowController.swift | 3 | Window title, quit menu, frame key |
| Sources/MacPerformance/Monitoring/MemoryReader.swift | 1 | Comment reference |
| Sources/MacPerformance/Views/PerformanceWidgetView.swift | 2 | Header text + comment |

### Build Artifact Paths

| Path | Current Value |
|------|---------------|
| Debug binary | `.build/debug/MacPerformance` |
| Debug app | `.build/debug/MacPerformance.app` |
| Release binary | `.build/release/MacPerformance` |
| Release app | `.build/release/MacPerformance.app` |
| dSYM | `.build/*/MacPerformance.dSYM` |

### Source Code Identifiers (Internal)

| File | Identifier | Rationale |
|------|------------|-----------|
| `MacPerformanceApp.swift` | `MacPerformanceApp` | App entry point — **public-facing, should rename** |
| `PerformanceWidgetView.swift` | `PerformanceWidgetView` | Generic view name — **can remain** |
| `MetricHistogramRow.swift` | `MetricHistogramRow` | Generic — **can remain** |
| `MetricProgressRow.swift` | `MetricProgressRow` | Generic — **can remain** |
| `MiniHistogram.swift` | `MiniHistogram` | Generic — **can remain** |
| `SecondaryMetricRow.swift` | `SecondaryMetricRow` | Generic — **can remain** |
| `ByteRate.swift` | `ByteRate` | Generic — **can remain** |
| `SystemStats.swift` | `SystemStats` | Generic — **can remain** |
| `PerformanceModel.swift` | `PerformanceModel` | Generic — **can remain** |
| `SystemMonitor.swift` | `SystemMonitor` | Generic — **can remain** |
| `MetricSampler.swift` | `MetricSampler` | Generic — **can remain** |
| `CPUReader.swift` | `CPUReader` | Generic — **can remain** |
| `GPUReader.swift` | `GPUReader` | Generic — **can remain** |
| `MemoryReader.swift` | `MemoryReader` | Generic — **can remain** |
| `NetworkReader.swift` | `NetworkReader` | Generic — **can remain** |
| `DiskReader.swift` | `DiskReader` | Generic — **can remain** |
| `PowerReader.swift` | `PowerReader` | Generic — **can remain** |
| `TemperatureReader.swift` | `TemperatureReader` | Generic — **can remain** |

**Rule:** Only rename identifiers that are **public/product-facing** (App struct, executable, bundle ID, display name, repo name). Internal implementation types with generic names (PerformanceWidgetView, SystemMonitor, etc.) should stay as-is to avoid noisy diffs.

---

## 2. REBRAND MIGRATION MAP

### Files Requiring Changes

| File | Change Type | Details |
|------|-------------|---------|
| `Package.swift` | Product/Target/Package name | Lines 5, 10, 13, 14 |
| `scripts/make-app.sh` | Paths, Info.plist template | Lines 2-3, 10-11, 30, 32, 34, 40, 52 |
| `scripts/build.sh` | Comment header | Line 2 |
| `scripts/run.sh` | App paths | Lines referencing MacPerformance.app |
| `Sources/MacPerformance/App/MacPerformanceApp.swift` | Struct name | Line 1 |
| `Sources/MacPerformance/App/WindowController.swift` | Window title, quit menu, frame key | Lines with "MacPerformance" |
| `Sources/MacPerformance/Views/PerformanceWidgetView.swift` | Header text "MacPerformance" | UI display string |
| `Sources/MacPerformance/Monitoring/MemoryReader.swift` | Comment reference | Line with "MacPerformance v0.1" |
| `README.md` | Title + references | Line 1 |
| `ARCHITECTURE.md` | Header + module reference | Line 1, module list |
| `DECISIONS.md` | Build artifact reference | One occurrence |
| `DEVELOPMENT.md` | Header + paths | Header + 2 paths |
| `PROJECT_STATE.md` | Header + multiple references | Header + 6 refs |

### Files NOT Requiring Changes (Generic Names)

All monitoring readers, view components, models, and utilities with generic names stay unchanged.

---

## 3. USERDEFAULTS / PERSISTENCE MIGRATION STRATEGY

### Current State
- **Domain:** `local.MacPerformance` (CFBundleIdentifier)
- **Key:** `MacPerformance.windowFrame` with versioned value `v2|<NSRect>`

### Migration Strategy (Recommended)

**Approach: Bundle Identifier Transition with Domain Migration**

1. **Keep CFBundleIdentifier as `local.MacPerformance` for v2.1** — This preserves the UserDefaults domain so existing users' window positions persist automatically.

2. **On v2.2+ (or when ready for professional identifier):** Change to new bundle identifier (e.g., `io.github.Giovanni-Vespasiani.<newname>`) and implement one-time migration on first launch:

```swift
// In WindowController.init or App delegate
private static let legacyFrameKey = "MacPerformance.windowFrame"
private static let newFrameKey = "<NewName>.windowFrame"

func migrateLegacyPreferences() {
    let defaults = UserDefaults.standard
    if let legacy = defaults.string(forKey: Self.legacyFrameKey),
       defaults.string(forKey: Self.newFrameKey) == nil {
        defaults.set(legacy, forKey: Self.newFrameKey)
        // Optionally remove legacy key after successful migration
    }
}
```

3. **Rationale:** This is the cleanest long-term approach — no orphaned preferences, seamless user experience, and the app behaves as a continuation rather than a fresh install.

4. **Alternative (rejected):** Change bundle ID immediately in v2.1 — would reset window position for all existing users, poor UX.

---

## 4. BUNDLE IDENTIFIER STRATEGY

### Recommended Pattern

```
io.github.Giovanni-Vespasiani.<kebab-case-new-name>
```

### Examples (depending on final name)

| Candidate Name | Bundle Identifier |
|----------------|-------------------|
| Silhouette | `io.github.Giovanni-Vespasiani.silhouette` |
| Vitals | `io.github.Giovanni-Vespasiani.vitals` |
| Pulse | `io.github.Giovanni-Vespasiani.pulse` |
| Glance | `io.github.Giovanni-Vespasiani.glance` |
| Prism | `io.github.Giovanni-Vespasiani.prism` |

### Evaluation Criteria

| Criterion | Assessment |
|-----------|------------|
| **Stability** | ✓ Reverse-DNS with GitHub identity — stable, owned namespace |
| **Future signing/notarization** | ✓ Compatible with Apple Developer ID requirements |
| **Homebrew distribution** | ✓ Standard pattern for open-source macOS apps |
| **Uniqueness** | ✓ GitHub username namespace guarantees uniqueness |
| **Professional** | ✓ Clear, standard, recognizable |

### Decision (Pending Name)

The pattern is decided. The final identifier will be set once the name is approved. For v2.1, we **retain `local.MacPerformance`** to preserve UserDefaults continuity.

---

## 5. GITHUB REPOSITORY RENAME STRATEGY

### Current State
- **Repository:** `Giovanni-Vespasiani/MacPerformance` (Private)
- **Remote:** `origin` → `git@github-personal:Giovanni-Vespasiani/MacPerformance.git`

### Procedure (When Name Approved)

1. **On GitHub Web UI:** Settings → General → Repository name → Rename to `<new-name>`
2. **Local remote update:**
   ```bash
   git remote set-url origin git@github-personal:Giovanni-Vespasiani/<new-name>.git
   ```
3. **Verify:**
   ```bash
   git remote -v
   git fetch origin
   git status
   ```

### Preservation Guarantees
- ✅ Full Git history preserved
- ✅ Tags preserved (v2.0.0 remains)
- ✅ Issues/PRs preserved (none currently)
- ✅ Existing clones work with `git remote set-url`
- ✅ No force push required

---

## 6. SOURCE RENAME STRATEGY

### Must Rename (Public/Product-Facing)
| Item | Current | New Pattern |
|------|---------|-------------|
| SPM Package/Product/Target | `MacPerformance` | `<NewName>` (PascalCase) |
| Executable | `MacPerformance` | `<NewName>` |
| App Bundle | `MacPerformance.app` | `<NewName>.app` |
| CFBundleDisplayName | `MacPerformance` | `<NewName>` |
| CFBundleName | `MacPerformance` | `<NewName>` |
| CFBundleIdentifier | `local.MacPerformance` | `io.github.Giovanni-Vespasiani.<kebab-new-name>` |
| App Struct | `MacPerformanceApp` | `<NewName>App` |
| Window Title | `MacPerformance` | `<NewName>` |
| Quit Menu | `Quit MacPerformance` | `Quit <NewName>` |
| Frame Key | `MacPerformance.windowFrame` | `<NewName>.windowFrame` |
| UI Header Text | `MacPerformance` | `<NewName>` |
| GitHub Repo | `MacPerformance` | `<new-name>` (kebab-case) |

### Keep As-Is (Generic Implementation)
All internal types: `PerformanceWidgetView`, `PerformanceModel`, `SystemMonitor`, `MetricSampler`, `*Reader`, `*Row`, `MiniHistogram`, `ByteRate`, `SystemStats`, etc.

**Rationale:** These are implementation details. Renaming them creates massive diffs with zero user value.

---

## 7. VERSIONING POLICY

| Version | Meaning |
|---------|---------|
| **v2.0.0** | Stable pre-rebrand release (TAGGED) — rollback point |
| **v2.1.0** | Completed rebrand / public identity |
| **v2.2.0** | Hardening (error handling, edge cases) |
| **v2.3.0** | Tests + CI |
| **v2.4.0** | Public-readiness release (license, docs, signing) |

Current HEAD: `502b036` (v2.1 development started)

---

## 8. NAMING CANDIDATES — BROAD SET (20+)

| # | Name | Concept |
|---|------|---------|
| 1 | **Silhouette** | Outline/shadow — the widget is a dark silhouette on the desktop |
| 2 | **Vitals** | Medical metaphor — checking your Mac's vital signs |
| 3 | **Pulse** | Heartbeat — live, rhythmic, real-time |
| 4 | **Glance** | "At a glance" — the positioning phrase |
| 5 | **Prism** | Light through glass — the dark glass panel aesthetic |
| 6 | **Scope** | Oscilloscope / telescope — viewing internals |
| 7 | **Signal** | Clean signal — real data, no noise |
| 8 | **Radar** | Scanning — continuous monitoring |
| 9 | **Beacon** | Guiding light — always visible on desktop |
| 10 | **Lens** | Magnifying glass — inspecting the system |
| 11 | **Gauge** | Instrument — precise measurement |
| 12 | **Meter** | Measurement device — straightforward |
| 13 | **Dial** | Analog control — tactile, native feel |
| 14 | **Panel** | Control panel — utilitarian, Apple-like |
| 15 | **HUD** | Heads-up display — overlay metaphor |
| 16 | **Vista** | View — broad perspective |
| 17 | **Core** | Central — Apple Silicon core, system core |
| 18 | **Flux** | Flow/change — dynamic metrics |
| 19 | **Echo** | Reflection — the widget mirrors the system |
| 20 | **Trace** | Tracing — following execution |
| 21 | **Vertex** | Peak point — performance peaks |
| 22 | **Strata** | Layers — the window layering, system layers |

---

## 9. SHORTLIST — TOP 5 CANDIDATES

### 1. **Silhouette**

| Aspect | Evaluation |
|--------|------------|
| **Meaning** | Dark outline against light — matches the dark glass panel on desktop wallpaper |
| **Why it fits** | Visual metaphor for the widget: a dark silhouette on the desktop; premium, Apple-like |
| **Strengths** | Unique, memorable, visual, premium feel, 4 syllables but flows well |
| **Weaknesses** | Longer (10 chars); "silhouette" spelling can trip some |
| **Conflicts** | Some design tools, no major macOS apps |
| **GitHub suitability** | `silhouette` — likely taken, but `silhouette-monitor` or `silhouette-app` available |
| **Future Apple Silicon/AI** | ✓ Neutral — works for any metrics |
| **Brandability** | 9/10 — Strong visual identity potential |
| **Technical suitability** | 8/10 — Good for CLI (`silhouette`), bundle (`io.github...silhouette`) |

---

### 2. **Vitals**

| Aspect | Evaluation |
|--------|------------|
| **Meaning** | Vital signs — CPU, GPU, Memory, Power, Network, Disk as "vitals" |
| **Why it fits** | Direct semantic match: monitoring system health/vitals; medical precision |
| **Strengths** | Short (6), clear meaning, professional, "check your Mac's vitals" |
| **Weaknesses** | Medical apps use this term; plural noun as app name slightly unusual |
| **Conflicts** | `Vitals` exists as iOS health apps; macOS menu-bar apps |
| **GitHub suitability** | `vitals` — taken, but `vitals-monitor` / `vitals-app` viable |
| **Future Apple Silicon/AI** | ✓ Extensible — "AI vitals", "thermal vitals" |
| **Brandability** | 8/10 — Clear concept, professional |
| **Technical suitability** | 9/10 — Short, `vitals` CLI, clean bundle ID |

---

### 3. **Pulse**

| Aspect | Evaluation |
|--------|------------|
| **Meaning** | Heartbeat / rhythm — 1 Hz sampling, live pulse of the system |
| **Why it fits** | Dynamic, alive, real-time; "feel the pulse of your Mac" |
| **Strengths** | Very short (5), one syllable, verb+noun, energetic |
| **Weaknesses** | Very common term; many apps/libraries named Pulse |
| **Conflicts** | Pulse (GitHub), Pulse (macOS menu bar apps), Pulse Secure (VPN) |
| **GitHub suitability** | `pulse` — heavily taken; would need qualifier |
| **Future Apple Silicon/AI** | ✓ Neutral |
| **Brandability** | 7/10 — Strong verb, but crowded space |
| **Technical suitability** | 7/10 — Name collisions likely |

---

### 4. **Glance**

| Aspect | Evaluation |
|--------|------------|
| **Meaning** | "At a glance" — the positioning phrase made into the name |
| **Why it fits** | Directly embodies the product promise; calm, effortless |
| **Strengths** | 6 letters, one syllable, unique positioning tie-in, calm |
| **Weaknesses** | "Glance" used by note-taking apps, screen capture tools |
| **Conflicts** | Glance (screen capture), Glance (weather), several iOS apps |
| **GitHub suitability** | `glance` — taken; `glance-monitor` possible |
| **Future Apple Silicon/AI** | ✓ Works — "AI glance" |
| **Brandability** | 8/10 — Ties perfectly to positioning |
| **Technical suitability** | 8/10 — Short, clean |

---

### 5. **Prism**

| Aspect | Evaluation |
|--------|------------|
| **Meaning** | Light through glass — splits white light into spectrum; the dark glass panel reveals system internals |
| **Why it fits** | Visual metaphor for the glass panel UI; Apple-like (PRISM, Metal, Core* naming); premium |
| **Strengths** | 5 letters, distinctive, Apple-adjacent naming style, strong icon potential |
| **Weaknesses** | Apple's PRISM (internal); Prism (macOS window manager by Knoll); Prism (code syntax highlighter) |
| **Conflicts** | Prism.app (window manager), Prism.js (syntax highlighter) |
| **GitHub suitability** | `prism` — taken; `prism-monitor` / `prism-sys` viable |
| **Future Apple Silicon/AI** | ✓ "AI prism" — refracting complexity into clarity |
| **Brandability** | 9/10 — Premium, Apple-native feel, strong visual |
| **Technical suitability** | 8/10 — Good CLI, bundle ID, some collisions |

---

## 10. RECOMMENDED TOP 3

| Rank | Name | Overall Score | Rationale |
|------|------|---------------|-----------|
| **1** | **Silhouette** | 8.5/10 | Best visual metaphor for the dark glass panel; unique; premium Apple-like feel; strong brandability; minor spelling length |
| **2** | **Prism** | 8.5/10 | Apple-native naming style (Core*, Metal, Prism); glass metaphor perfect for UI; premium; some existing collisions but manageable |
| **3** | **Vitals** | 8/10 | Clear semantic fit for system monitoring; professional; short; medical apps use it but different category |

---

## 11. APP ICON REQUIREMENTS (Future v2.1-B)

| Requirement | Details |
|-------------|---------|
| **Recognizable at 16px** | Must work as Dock/icon badge at tiny size |
| **Simple** | 1-2 visual elements max; no text |
| **Premium** | Apple-design-language quality |
| **macOS-native feel** | Rounded square, subtle gradient/glass, consistent with system icons |
| **Not Activity Monitor clone** | No speedometer, gauge, or chart clichés |
| **Not Apple logo derivative** | No bitten apple, leaf, or Apple color palette mimicry |
| **Not overly technical** | No circuit boards, binary, terminal glyphs |
| **Scalable 16–1024px** | Vector source (SF Symbols style or custom SVG) |
| **GitHub avatar ready** | Circular crop works at 40px |
| **Dark mode native** | Designed for dark appearance primarily |

**Icon concept direction per top candidate:**
- **Silhouette:** Minimal dark shape (MacBook outline or abstract panel) with subtle inner glow
- **Prism:** Triangular prism with subtle light spectrum emerging — glass/refraction metaphor
- **Vitals:** Clean line waveform (ECG-style) or abstract "pulse" dot with rings

---

## 12. INTERNET-BASED COLLISION CHECKS (Preliminary)

> **Note:** These are quick searches via web search tool, not legal trademark clearance.

| Name | GitHub Repos | macOS Apps (known) | Homebrew | Obvious TM |
|------|--------------|-------------------|----------|------------|
| Silhouette | Many (design tools) | None major | No | No |
| Vitals | Many (health) | iOS health apps | No | Medical TM common |
| Pulse | Hundreds | Menu bar apps, VPN | `pulse` (audio) | Heavy use |
| Glance | Many (capture, weather) | Screen capture tools | No | Generic |
| Prism | Many (window mgr, syntax) | Prism.app (Knoll) | `prism` (syntax) | Apple internal |

**Conclusion:** All top candidates have some collisions (expected for short English words). The key is differentiation via category (system monitor vs. design tool vs. health app) and qualified GitHub repo names (`silhouette-monitor`, `vitals-app`, `prism-sys`).

---

## 13. IMPLEMENTATION CHECKLIST (v2.1-B — After Name Approval)

- [ ] Update `Package.swift` — package/product/target name
- [ ] Update `scripts/make-app.sh` — paths, Info.plist template (display name, bundle ID, executable)
- [ ] Update `scripts/build.sh` — comment
- [ ] Update `scripts/run.sh` — app paths
- [ ] Rename `MacPerformanceApp.swift` → `<NewName>App.swift`, update struct
- [ ] Update `WindowController.swift` — window title, quit menu, frame key
- [ ] Update `PerformanceWidgetView.swift` — header text
- [ ] Update `MemoryReader.swift` — comment reference
- [ ] Update `README.md` — title
- [ ] Update `ARCHITECTURE.md` — header, module reference
- [ ] Update `DECISIONS.md` — build reference
- [ ] Update `DEVELOPMENT.md` — header, paths
- [ ] Update `PROJECT_STATE.md` — header, references
- [ ] Rename GitHub repository via web UI
- [ ] Update local `origin` remote URL
- [ ] Commit as `feat: rebrand to <NewName> — v2.1.0`
- [ ] Tag `v2.1.0`
- [ ] Push tag and commit

---

## 14. DECISIONS LOG

| Decision | Status |
|----------|--------|
| D-R001: Retain `local.MacPerformance` bundle ID for v2.1 to preserve UserDefaults | **DECIDED** |
| D-R002: Migration strategy = keep legacy domain, migrate on future bundle ID change | **DECIDED** |
| D-R003: Bundle ID pattern = `io.github.Giovanni-Vespasiani.<kebab-name>` | **DECIDED** |
| D-R004: Only rename public-facing identifiers; keep generic internal names | **DECIDED** |
| D-R005: GitHub repo rename procedure documented; preserves history/tags | **DECIDED** |
| D-R006: Versioning: v2.0.0 freeze → v2.1.0 rebrand → v2.2 hardening → v2.3 tests → v2.4 public | **DECIDED** |
| D-R007: Final brand name = **PulsePane** | **DECIDED** |

---

## 15. DOCUMENTATION STATUS

| Document | Updated for v2.1-A | Updated for v2.1-B |
|----------|-------------------|-------------------|
| PROJECT_STATE.md | ✓ | ✓ |
| DECISIONS.md | ✓ | ✓ |
| REBRAND_PLAN.md | ✓ | ✓ |
| DEVELOPMENT.md | Pending | ✓ |
| ARCHITECTURE.md | Not needed | ✓ |
| README.md | Not yet | ✓ |

---

## 16. IMPLEMENTATION COMPLETION CHECKLIST (v2.1-B)

- [x] Update `Package.swift` — package/product/target name → PulsePane
- [x] Update `scripts/make-app.sh` — paths, Info.plist template (display name, bundle ID, executable)
- [x] Update `scripts/build.sh` — comment
- [x] Update `scripts/run.sh` — app paths
- [x] Rename `MacPerformanceApp.swift` → `PulsePaneApp.swift`, update struct
- [x] Update `WindowController.swift` — window title, quit menu, frame key, **legacy preference migration**
- [x] Update `PerformanceWidgetView.swift` — header text "PulsePane"
- [x] Update `MemoryReader.swift` — comment reference
- [x] Update `README.md` — title, branding, paths
- [x] Update `ARCHITECTURE.md` — header, module reference
- [x] Update `DECISIONS.md` — D-R007 decision recorded
- [x] Update `DEVELOPMENT.md` — header, paths, GitHub remote
- [x] Update `PROJECT_STATE.md` — header, references, GitHub remote
- [x] Update `REBRAND_PLAN.md` — completion status
- [x] Rename local project directory `MacPerformance` → `PulsePane`
- [x] Rename GitHub repository via web UI → `Giovanni-Vespasiani/PulsePane`
- [x] Update local `origin` remote URL
- [x] Commit as `feat: rebrand to PulsePane — v2.1.0`
- [x] Tag `v2.1.0`
- [x] Push tag and commit

---

## 17. FINAL IDENTITY SUMMARY

| Element | Old (MacPerformance) | New (PulsePane) |
|---------|---------------------|-----------------|
| Product Name | MacPerformance | PulsePane |
| Application Display Name | MacPerformance | PulsePane |
| Executable | MacPerformance | PulsePane |
| SPM Product | MacPerformance | PulsePane |
| SPM Target | MacPerformance | PulsePane |
| SPM Package Name | MacPerformance | PulsePane |
| Bundle Identifier | `local.MacPerformance` | `io.github.Giovanni-Vespasiani.PulsePane` |
| App Bundle | `MacPerformance.app` | `PulsePane.app` |
| GitHub Repository | `Giovanni-Vespasiani/MacPerformance` | `Giovanni-Vespasiani/PulsePane` |
| GitHub Remote URL | `git@github-personal:Giovanni-Vespasiani/MacPerformance.git` | `git@github-personal:Giovanni-Vespasiani/PulsePane.git` |
| Window Title | MacPerformance | PulsePane |
| Quit Menu Item | "Quit MacPerformance" | "Quit PulsePane" |
| UserDefaults Frame Key | `MacPerformance.windowFrame` | `PulsePane.windowFrame` |
| Migration Version Key | — | `PulsePane.migrationVersion` |
| Local Project Path | `~/Projects/MacPerformance` | `~/Projects/PulsePane` |

---

## 18. LEGACY REFERENCES — INTENTIONAL REMAINING

The following legacy references are intentionally preserved:

| File | Reference | Reason |
|------|-----------|--------|
| `docs/REBRAND_PLAN.md` | Multiple "MacPerformance" | Historical rebrand documentation |
| `DECISIONS.md` | D-001, D-005, D-006, D-009, D-010, D-011, D-012, D-013, D-014, D-R001–D-R006 | Historical architecture decisions |
| `PROJECT_STATE.md` | Historical v2.0/v1 references | Operational checkpoint history |
| `ARCHITECTURE.md` | GPU implementation notes | Historical architecture notes |

No accidental remaining references in active source code, build scripts, or user-facing strings.

---

*End of REBRAND_PLAN.md — **Status: COMPLETED** — PulsePane v2.1.0*