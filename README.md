# MacSweep 🧹

**MacSweep** is a native macOS storage-cleanup and disk inspection application written in **SwiftUI**. Inspired by reverse-engineering `/Applications/AppCleaner.app` using **REA**, MacSweep extends that workflow into a full-system storage analyzer, app uninstaller, browser profile cleaner, developer artifact manager, and ranked storage explorer.

---

## 🔍 AppCleaner Insights Discovered via REA

Using REA reverse-engineering against `/Applications/AppCleaner.app`, we analyzed its internal Mach-O binary and Hopper pseudocode to understand its discovery algorithms:
1. **Application Inspection (`ACBundle` / `ACAppBundle`)**:
   - Rather than relying on static lists, AppCleaner inspects bundle identifiers (`CFBundleIdentifier`) and locates related files dynamically across:
     - `~/Library/Preferences/<bundleId>.plist`
     - `~/Library/Caches/<bundleId>`
     - `~/Library/Application Support/<appName>` & `<bundleId>`
     - `~/Library/Containers/<bundleId>` & `~/Library/Group Containers`
     - `~/Library/Saved Application State/<bundleId>.savedState`
     - `~/Library/LaunchAgents` & `/Library/LaunchAgents`
     - `~/Library/Logs/<appName>` & `<bundleId>`
     - `~/Library/WebKit/<bundleId>` & `~/Library/HTTPStorages/<bundleId>`
2. **Safe Removal (`recycle`)**:
   - AppCleaner uses macOS `recycle` / `trashItemAtURL` rather than destructive `rm -rf`, preserving user recoverability.
3. **Protected Paths (`+[ACBundle protectedPaths]`)**:
   - System root directories, core Apple frameworks, and critical Library roots are strictly protected against accidental deletion.

### How MacSweep Enhances This:
- **No Drag-and-Drop Required**: Automatically indexes all installed applications in `/Applications` and `~/Applications`, plus detects **orphaned leftovers** from previously uninstalled applications.
- **Interactive Storage Explorer & Power Commands**: Allows drilling down into any high-consumption directory level by level, providing copyable terminal commands (`cd`, `du -sh`, `open`) as requested.
- **Chromium & Safari Browser Cleaning**: Dedicated Chromium profile inspector (Chrome, Arc, Brave, Edge, Vivaldi) with a prominent **"Keep my passwords and existing website sign-ins"** toggle enabled by default.
- **Developer Artifacts & Rebuild Steps**: Distinguishes rebuildable items (`node_modules`, Xcode `DerivedData`, build outputs) from source code and credentials, providing the exact rebuild command (`npm install`, `xcodebuild`, `cargo build`).
- **Cryptographic Duplicate Detection**: Validates duplicates using **chunked SHA-256 content hashing**, avoiding false positives based on filename matching.
- **APFS Awareness & Verification**: Clarifies that moving files to the Trash retains space until Trash is emptied, and logs verified before/after free space measurements.

---

## 🚀 Key Features

### 1. Storage Scan & Explanation
- **Disk Visualizer**: Boot volume capacity, allocated space, and free space gauge.
- **Ranked Consumption**: Ranked folders and categories by actual APFS allocated blocks (`fileAllocatedSize`).
- **Safe Defaults**: Disposable caches and temporary files selected by default; settings, projects, and personal data unselected.

### 2. Candidate Explanations
Every candidate provides:
- Human-readable name and exact filesystem path.
- What it contains and why it exists.
- Removal consequence and rebuildability (with rebuild steps).
- Impact flags for sign-ins, settings, or unsynced offline work.
- Confidence rating (`Verified`, `High`, `Heuristic`, `Unknown / Review Needed`).

### 3. Focused Cleanup Modes
- **Apps & Leftovers**: Application binary size vs caches vs preferences vs containers. Actions for "Clear Caches", "Reset Local Data", and "Uninstall App". Includes detection of orphaned leftovers.
- **Browser Data**: Chrome, Arc, Brave, Edge, Safari. Prominent "Keep my passwords & sign-ins" switch preserves cookies and auth vaults.
- **Developer Files**: Xcode `DerivedData`, archives, `node_modules`, `.next`, `dist`, package manager caches (npm, pnpm, Bun, Yarn, Cargo, Homebrew).
- **Large & Duplicate Files**: Files > 50MB with SHA-256 duplicate verification, Quick Look, and Finder reveal.
- **Storage Explorer**: Drill-down directory tree ranked by size with instant copy for terminal commands (`cd`, `du`, `open`).

### 4. Batch Review & Safe Deletion
- **Batch Review Sheet**: Shows concrete review plan before any deletion occurs.
- **Nested Deduplication**: Eliminates redundant child deletion when parent directory is targeted.
- **Running App Detection**: Gracefully requests affected running apps to close (`terminate()`), never force-kills.
- **Trash Preference**: Uses `FileManager.trashItem` for full recoverability via macOS Trash "Put Back".
- **Dry Run Simulation Mode**: Simulates the entire plan without modifying any file on disk.

### 5. Verification & Cleanup History
- Measures volume free space before and after execution.
- Itemized logs preserved locally in `~/Library/Application Support/MacSweep/cleanup_history.json`.
- Complete restore guidance for macOS Trash.

---

## 🛠 Building & Running

### Requirements
- macOS 14.0 (Sonoma) or newer
- Swift 6.0+ / Xcode 16+

### Quick Run
```bash
# Clone or navigate to the repository
cd MacSweep

# Run directly via Swift Package Manager
swift run
```

### Build Native `.app` Bundle
```bash
# Build release bundle
./build_app.sh

# Launch the app
open MacSweep.app
```

### Build Downloadable Apple Silicon DMG
```bash
# Compiles arm64 release binary and packages into a compressed DMG
./build_dmg.sh

# Outputs: MacSweep-AppleSilicon.dmg
open MacSweep-AppleSilicon.dmg
```

### Build for Mac App Store Submission
```bash
# Sandboxes the app using MacSweep.entitlements and packages into an App Store PKG
./build_appstore.sh

# Outputs: MacSweep.pkg (ready for upload via Apple Transporter)
```

### Run Automated Test Suite
```bash
swift test
```
The test suite validates:
- Path safety protection (root, `/System`, `~/.ssh`, `~/.zshrc`).
- Nested path deduplication.
- Dry run simulation mode (zero modifications to disk).
- Recoverable cleanup to Trash.
- SHA-256 content duplicate verification.
- Terminal command formatting and escaping.
- Full Disk Access permission verification (`DiskPermissionService`).
- Targeted CleanupPlan candidate isolation.

---

## ⚠️ Honest List of Unsupported Cleanup Operations

1. **System Integrity Protection (SIP) & Sealed System Volume (SSV)**:
   - MacSweep does NOT attempt to delete or modify Apple system files located on the signed/sealed system volume (`/System`).
2. **Live Browser Database Modification**:
   - MacSweep will NOT alter or write into live browser SQLite databases while the browser is running. It requires the browser to be closed gracefully.
3. **APFS Local Snapshots**:
   - Moving items to the macOS Trash or deleting APFS cloned files does not instantly release physical disk blocks if an active Time Machine snapshot references them. These are managed directly by macOS `tmutil`.
4. **TCC-Restricted User Folders without Permission**:
   - Locations protected by macOS Transparency, Consent, and Control (such as Mailboxes or Safari Personal History) cannot be scanned without user-granted **Full Disk Access** in System Settings. MacSweep reports these as partial scan notices and does not force access.
5. **System Daemons / Protected Extensions**:
   - Third-party kernel or system extensions requiring root uninstallation scripts are reported as system-managed items requiring vendor uninstallers.
