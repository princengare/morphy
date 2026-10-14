# morphy

morphy is a small Mac app for the moment when you have a HEIC photo and need a JPEG, PNG, or WebP instead. It sits in your menu bar, watches a folder for new photos, and makes a converted copy without changing the original. You can also pick files yourself when you need to convert something that's already on your Mac.

Everything happens locally. There are no uploads, accounts, subscriptions, or analytics.

The interface is a pixel-art tree, with leaves for Export, History, and Settings. The green chameleon is morphy; its monochrome version lives in the menu bar. Each leaf-and-icon row is clickable across its full width. Hovering anywhere in the row highlights the leaf and animates its icon, while idle leaves flex in the wind at slightly different rates. Settings switches and the folder button use the same pixel-art style. These effects respect macOS Reduce Motion.

**Current version: 0.3.3.** This is a working development build, not an App Store release.

## What It Does

- Converts HEIC and HEIF still images to JPEG (`.jpg`), PNG, or WebP.
- Automatically converts new photos arriving in a selected folder, including AirDrop transfers saved there.
- Lets you choose multiple files for manual conversion.
- Offers Smaller File, Recommended, and Best Quality presets for JPEG and WebP. PNG does not use a lossy quality setting.
- Saves converted copies next to the originals, adding a number when a filename is already taken.
- Keeps a local conversion history, with an option to reveal an output in Finder.
- Remembers your format, quality, and watched-folder settings between launches.

morphy keeps your originals. Clearing the history only clears the records; it doesn't delete any photos.

## Download And Install

### What You Need

- An Apple silicon Mac, such as an M1, M2, M3, or newer model.
- macOS 14 Sonoma or later.

The packaged build is for Macs only. It does not run on iPhone, iPad, Android, or Windows, and Intel Macs are not supported by this package. You do not need Xcode, Swift, or Homebrew to use it.

### Download From GitHub

The latest packaged app is included in the [morphy GitHub repository](https://github.com/princengare/morphy), so you don't need to build it yourself.

1. Open [morphy-0.3.3-apple-silicon.zip](dist/morphy-0.3.3-apple-silicon.zip) on GitHub and click **Download raw file**. You can also find it by opening the repository's `dist` folder. Download the app ZIP, not GitHub's **Download ZIP** source-code archive.
2. Double-click the ZIP to extract `Morphy.app`.
3. Drag `Morphy.app` into your Applications folder.
4. Open Morphy from Applications.
5. Click the chameleon in the menu bar, then choose **open morphy**.

morphy runs from the menu bar, so you won't see a normal Dock icon. Closing its window doesn't quit the app.

Finder shows the installed app as **Morphy**. The interface and menu labels still use lowercase **morphy**.

The menu has three entries: **changing**, **open morphy**, and **quit morphy**. Hover over changing to reveal automatic conversion, output format, and quality settings. You can also click it to keep those controls open while using the keyboard.

If you cloned the repository, the same installable ZIP is in `dist`. To install on another compatible Mac, transfer that ZIP using AirDrop, a USB drive, or another file transfer method.

### If macOS Blocks It

This development build has an ad-hoc local signature. It is not Developer ID signed or Apple notarized, so macOS may block it, especially after a transfer to another Mac.

Only proceed if you trust where the app came from. After trying to open it, go to **System Settings > Privacy & Security**, find morphy's warning, and choose **Open Anyway** if that option is available. This approves the individual app; you don't need to disable Gatekeeper. See [Apple's guidance on opening an unnotarized app](https://support.apple.com/en-us/102445).

To update an existing installation, choose **quit morphy** from its menu-bar menu before replacing the app in Applications. Open the new copy afterward.

## Your First Conversion

For automatic conversion:

1. Open morphy and select the Settings leaf.
2. Turn on **Watch for New Photos**.
3. Set **Default Format** to JPEG, PNG, or WebP.
4. Check **Watched Folder**. Downloads is the default; use the folder picker to choose somewhere else or grant access when needed.
5. Leave morphy running and send a new HEIC or HEIF photo to that folder.

morphy notices the incoming file straight away, but waits until the transfer is complete and the image is readable before converting it. This is normally about 1.5 seconds after the last write, followed by the time needed to encode the image. The converted copy appears beside the original.

For example, with Downloads watched and JPEG selected, an AirDropped `IMG_1234.HEIC` saved into Downloads produces `IMG_1234.jpg` in the same folder. If that name already exists, morphy adds a number instead of overwriting it.

AirDrop is not a separate integration: morphy watches the receiving folder. If a photo goes directly into Photos or another location, it won't be picked up unless it also arrives in the watched folder. Files that were already there when monitoring started are left alone, and subfolders aren't watched.

For an older photo, open the Export leaf, choose your format and quality, and select **Choose Files**. Manual and automatic conversions use the same queue.

On the conversion screen, morphy cycles through colors for at least three seconds. If the job is ready by then, you'll see **Conversion Completed**. Otherwise, the colors keep cycling until it finishes. This is only a display delay; converted files are saved as soon as they're ready.

## Technical Specifications

| Area | Implementation |
| --- | --- |
| Version | 0.3.3 |
| Platform | macOS 14 or later; packaged for Apple silicon (`arm64`) |
| Language and build | Swift, Swift 6.2 toolchain, Swift Package Manager |
| Interface | Native SwiftUI, with AppKit for file pickers, Finder actions, and app integration |
| Image decoding | Apple's Image I/O and Core Graphics |
| JPEG and PNG encoding | Apple's Image I/O |
| WebP encoding | Statically bundled libwebp 1.6.0; no separate codec installation |
| Folder monitoring | Native filesystem events through DispatchSource, with file-stability checks |
| Job handling | One shared serial queue for manual and automatic conversion |
| Preferences | Local UserDefaults, including the selected folder's bookmark |
| History | Local JSON in `~/Library/Application Support/Morphy/conversion-history.json` |
| Distribution | `.app` bundle and ZIP, currently signed for local development only |

Before publishing a converted file, morphy checks available disk space, writes to a temporary file, and validates that the result can be decoded. It also checks that the source hasn't changed during conversion. Duplicate filesystem events are filtered so the same incoming file isn't queued repeatedly.

The source is split into three main targets: `MorphyApp` contains the interface and application state, `MorphyCore` contains conversion, monitoring, and persistence, and `CWebP` builds the bundled encoder. Tests cover file handling and actual HEIC conversion, including simulated incoming transfers. A complete AirDrop test from a second device is still pending.

## Build From Source

Building requires a Mac with Xcode or command-line tools that provide Swift 6.2 or later and the macOS SDK. Run these commands from the project folder.

Build and run during development:

```sh
swift build
swift run Morphy
```

Run the tests:

```sh
swift test
```

Create an installable app and ZIP on an Apple silicon Mac:

```sh
zsh Scripts/package-macos.sh
```

The packaging script builds a release binary, includes the artwork and WebP license, applies and verifies a local signature, and writes `dist/Morphy.app` and `dist/morphy-0.3.3-apple-silicon.zip`.

The newest ZIP is deliberately allowed through `.gitignore` so it can be committed and downloaded from GitHub. Other generated files and older, untracked builds stay ignored. After packaging succeeds, the script updates that ZIP exception and the version and package links in this README. Commit the new ZIP together with `.gitignore` and `README.md`, then push them to GitHub to publish the download. If a previous ZIP was already committed, remove its old repository entry when publishing its replacement; ignoring it does not remove a tracked file.

Internal development notes stay local and are not included in the public repository.

## A Few Things To Know

This version focuses on converting still images safely, not replacing a photo library or handling every HEIF feature.

- Only one folder is watched at a time. morphy must be running; launch at login isn't configured yet.
- Outputs are saved beside their sources. Choosing a separate output folder is not available yet.
- Keep Original is the only implemented original-file policy. Archive, Trash, and Ask are disabled.
- The Show Notifications setting is present, but system notifications are not implemented yet.
- WebP output preserves orientation and a compatible color profile, but does not copy camera EXIF or XMP tags. The original retains those details.
- Location metadata removal is available for JPEG and PNG, but broader metadata, HDR, and clean-account folder-access testing is still needed. Don't treat this build as a fully validated metadata scrubber.

## Uninstall

Choose **quit morphy** from the menu bar, then move Morphy from Applications to the Trash. There is no helper or special uninstaller. Your original and converted images stay where they are.

Local history remains in `~/Library/Application Support/Morphy/`. You can clear it in the app before uninstalling or remove that folder afterward if you don't want to keep the records.

## Licenses

See [Third-party licenses](THIRD_PARTY_LICENSES.md) for the bundled WebP encoder's license and patent notices.
