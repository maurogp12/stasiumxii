# STASIUM XII Mobile — Android export (ticket 1)

Mobile track only. This preset lives on the `mobile` branch. It stays off PC `main` until Mauro green-lights a merge.

`project.godot` display settings are unchanged:

- viewport `960×720`
- stretch mode `canvas_items`
- stretch aspect `expand`

Combat rules, kits, hit bands, maps, and the PC HUD are untouched.

## Preset

`export_presets.cfg` adds one Godot 4.7 Android preset named `Android` (the runnable preset). Debug and release are export modes of that preset (`Export With Debug` in the editor, or `--export-debug` / `--export-release` on the CLI). Official templates are used: `custom_template/debug` and `custom_template/release` are empty, and Gradle build is off.

| Option | Value |
| --- | --- |
| Package id | `com.maurogp12.stasiumxii.mobile` |
| Launcher name | `STASIUM XII` |
| Version | name `0.1.0-mobile`, code `1` |
| Format | APK (`gradle_build/export_format=0`) |
| ABI | `arm64-v8a` only |
| Min / target SDK | blank (engine defaults: target SDK 36; Vulkan min SDK 29 when the mobile renderer uses Vulkan) |
| Signing | on, keystores left empty (no secrets in git) |
| Permission | `INTERNET` (online lobby). Every other Android permission is off |
| Screen | immersive mode on. This hides the system bars. It does not change the 960×720 viewport |
| Output path | `builds/android/stasiumxii-mobile.apk` (`/builds/` is gitignored) |

An x86_64 emulator needs `architectures/x86_64` turned on in this preset. A physical arm64 phone matches the preset as committed.

Release signing uses a keystore that stays outside the repo. Godot 4.7 stores keystore paths and passwords in `.godot/export_credentials.cfg` (already gitignored) or in these environment variables:

- `GODOT_ANDROID_KEYSTORE_DEBUG_PATH` / `_USER` / `_PASSWORD`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` / `_PASSWORD`

## Smoke in this environment (2026-09-25)

Godot and the Android SDK were not installed. A temporary official editor binary `Godot v4.7.2.stable.official.ed1daf0bf` was used for the smoke and is not part of the commit. OpenJDK 21 is present at `/usr/lib/jvm/java-21-openjdk-amd64` and is not wired into Editor Settings.

Headless project load:

```text
godot --headless --path . --import --quit
```

Exit code 0. The editor imported the project (84 asset steps) and quit. `project.godot` display keys stayed `960` / `720` / `canvas_items` / `expand`.

Export (preset name was found; both modes failed before packaging):

```text
godot --headless --path . --export-debug "Android" /tmp/out/stasiumxii-mobile-debug.apk
godot --headless --path . --export-release "Android" /tmp/out/stasiumxii-mobile-release.apk
```

Both exited 1 with:

```text
Cannot export project with preset "Android" due to configuration errors:
No export template found at the expected path:
/home/ubuntu/.local/share/godot/export_templates/4.7.2.stable/android_debug.apk
No export template found at the expected path:
/home/ubuntu/.local/share/godot/export_templates/4.7.2.stable/android_release.apk
A valid Java SDK path is required in Editor Settings.
Invalid Android SDK path in Editor Settings. Missing 'platform-tools' directory!
Unable to find Android SDK platform-tools' adb command.
Invalid Android SDK path in Editor Settings. Missing 'build-tools' directory!
Unable to find Android SDK build-tools' apksigner command.
```

No APK was produced. No device was attached, so install/launch was not run.

## One-device smoke (Editor)

Use a Godot 4.7 editor. Export templates must match that editor's version string exactly (this smoke expected `4.7.2.stable`). Steps follow the Godot 4.7 "Exporting for Android" page.

1. Install Godot 4.7.x and open this project from the `mobile` branch.
2. **Editor → Manage Export Templates → Download and Install.** Confirm both files exist for that version:
   - `android_debug.apk`
   - `android_release.apk`
   - Linux path: `~/.local/share/godot/export_templates/<version>/`
3. Install OpenJDK 17 or newer (Godot 4.7 recommends 17; newer JDKs are supported).
4. Install the Android SDK with Android Studio or `sdkmanager`. Skip distro SDK packages. Godot 4.7 asks for:
   - Android SDK Platform-Tools 35.0.0 or later
   - Android SDK Build-Tools 35.0.1
   - Android SDK Platform 35
   - Android SDK Command-line Tools (latest)
   - CMake 3.10.2.4988404
   - NDK r28b (`28.1.13356709`)
5. **Editor → Editor Settings → Export → Android**
   - **Java SDK Path:** the JDK home (the directory that contains `bin/java`)
   - **Android SDK Path:** the SDK root that contains `platform-tools/adb`
6. **Project → Export.** The `Android` preset is already there. Leave the 960×720 display settings alone.
7. Debug install (the one-device smoke):
   - Turn on **Export With Debug**.
   - **Export Project** to `builds/android/stasiumxii-mobile-debug.apk` (create `builds/android/` first).
   - On the phone: Developer options, USB debugging, accept the computer's RSA prompt.
   - `adb devices` shows the phone as `device`.
   - `adb install -r builds/android/stasiumxii-mobile-debug.apk`
   - Launch **STASIUM XII**. Package id is `com.maurogp12.stasiumxii.mobile`.
8. If a previous install used the same package id and a different signing key, uninstall that app before installing again.

Release export (after the debug smoke, when a Play-bound build is wanted):

1. Create a release keystore outside the repo:

   ```text
   keytool -v -genkey -keystore mygame.keystore -alias mygame -keyalg RSA -validity 10000
   ```

   Keep the password. Godot currently needs the keystore password and the key password to be the same. Letters and digits only.
2. In the `Android` preset, set **Release**, **Release User**, and **Release Password**. Do not commit the keystore.
3. Export with **Export With Debug** unchecked.

CLI equivalents once templates, JDK, and SDK are configured (the output directory must already exist):

```text
godot --headless --path . --export-debug "Android" builds/android/stasiumxii-mobile-debug.apk
godot --headless --path . --export-release "Android" builds/android/stasiumxii-mobile-release.apk
```

## Blockers still open for a device APK

- Godot Android export templates for the editor version in use (`android_debug.apk` and `android_release.apk`).
- Editor Settings **Java SDK Path** (a JDK on disk is not enough until this path is set).
- Android SDK with `platform-tools` (`adb`) and `build-tools` (`apksigner`), and **Android SDK Path** set in Editor Settings.
- A physical arm64 device (or an arm64 emulator) with USB debugging. This environment had neither `adb` nor a device.
