# STASIUM XII Mobile — Android export (ticket 1)

Mobile track only. This preset lives on the `mobile` branch. It stays off PC `main` until Mauro green-lights a merge.

`project.godot` display settings are unchanged:

- viewport `960×720`
- stretch mode `canvas_items`
- stretch aspect `expand`

Godot 4.7 will not export this preset until `rendering/textures/vram_compression/import_etc2_astc` is true. That flag is on. Existing textures stay lossless (`compress/mode=0` in their `.import` files). The flag satisfies the exporter. It does not recompress art.

Combat rules, kits, hit bands, maps, and the PC HUD are untouched.

## Preset

`export_presets.cfg` adds one Godot 4.7 Android preset named `Android` (the runnable preset). Debug and release are export modes of that preset (`Export With Debug` in the editor, or `--export-debug` / `--export-release` on the CLI). Official templates are used: `custom_template/debug` and `custom_template/release` are empty, and Gradle build is off.

| Option | Value |
| --- | --- |
| Package id | `com.maurogp12.stasiumxii.mobile` |
| Launcher name | `STASIUM XII` |
| Version | name `0.1.7-mobile`, code `8` |
| Format | APK (`gradle_build/export_format=0`) |
| ABI | `arm64-v8a` only |
| Min / target SDK | blank in the preset. The debug APK below resolved to min SDK 24 and target SDK 36 |
| Signing | on, keystores left empty (no secrets in git) |
| Permission | `INTERNET` (online lobby). Every other Android permission is off |
| Screen | immersive mode on. This hides the system bars. It does not change the 960×720 viewport |
| Output path | `builds/android/stasiumxii-mobile.apk` (`/builds/` is gitignored) |

An x86_64 emulator needs `architectures/x86_64` turned on in this preset. A physical arm64 phone matches the preset as committed.

Release signing uses a keystore that stays outside the repo. Godot 4.7 stores keystore paths and passwords in `.godot/export_credentials.cfg` (already gitignored) or in these environment variables:

- `GODOT_ANDROID_KEYSTORE_DEBUG_PATH` / `_USER` / `_PASSWORD`
- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH` / `_USER` / `_PASSWORD`

## Debug APK (sideload)

Built 2026-09-25 on this branch with Godot `4.7.2.stable.official.ed1daf0bf` and the matching official templates (`android_debug.apk` and `android_release.apk` in `~/.local/share/godot/export_templates/4.7.2.stable/`). OpenJDK 21 was at `/usr/lib/jvm/java-21-openjdk-amd64`. The Android SDK root was `/home/ubuntu/android-sdk` (command-line tools `13114758`, platform-tools `37.0.1`, build-tools `35.0.1`). Editor Settings pointed Java and the SDK at those paths. The preset keystore fields stayed empty. Godot signed with the debug keystore it generated at `~/.local/share/godot/keystores/debug.keystore` (not in git).

```text
godot --headless --path . --export-debug "Android" builds/android/stasiumxii-mobile-debug.apk
```

Exit code 0. Godot aligned the APK, signed it, and printed `Verifying APK...` then `DONE`. `apksigner verify` (build-tools 35.0.1) reports APK Signature Scheme v2 and v3, one signer: `CN=Godot, OU=Godot Engine, O=Stichting Godot, C=NL`.

| Check | Result |
| --- | --- |
| Package | `com.maurogp12.stasiumxii.mobile` |
| Version | name `0.1.7-mobile`, code `8` |
| Debuggable | true |
| ABI | `arm64-v8a` only (`libgodot_android.so`) |
| Permission | `android.permission.INTERNET` only |
| Min / target SDK | 24 / 36 |
| GLES | 3.0 required |
| Vulkan features | declared, `required=false` |
| Renderer metadata | `org.godotengine.rendering.method=mobile` |
| Packed main scene | `res://scenes/mobile_hub.tscn` |
| Size | 36337823 bytes |
| SHA-256 | `90903532d860e1aa39aa4afb0e6cd3b7d3598273e20ab4230b5b188fbd405e31` |

`/builds/` is gitignored, so the APK is not in the commit. The sideload file is the cloud-agent artifact `stasiumxii-mobile-debug.apk` (same bytes). Godot also wrote `builds/android/stasiumxii-mobile-debug.apk.idsig` next to the APK. That idsig is not required to sideload.

Godot printed `Could not find version of build tools that matches Target SDK, using 35.0.1` and then signed with that build-tools. The export still finished and `apksigner verify` passed. No phone and no emulator were attached, so this environment did not run `adb install` or launch the app. The package is a signed debug build of this branch. On-device play was not observed here.

### Install on a phone

The APK is arm64. A 32-bit-only phone will reject it.

Without a computer:

1. Copy `stasiumxii-mobile-debug.apk` onto the phone.
2. Android 8 and later: **Settings → Apps → Special app access → Install unknown apps**, and allow the app that will open the file (Files, Chrome, or Drive). Older Android: **Settings → Security → Unknown sources**.
3. Open the APK and install.
4. Launch **STASIUM XII**.

USB, with Developer options and USB debugging on, and `adb devices` showing the phone as `device`:

```text
adb install -r stasiumxii-mobile-debug.apk
```

If Android reports that the package already exists with a different signature, uninstall first:

```text
adb uninstall com.maurogp12.stasiumxii.mobile && adb install -r stasiumxii-mobile-debug.apk
```

This debug key is not a Play release key. A later release-signed build of the same package id will not update over this install until the debug app is removed.

## Smoke in this environment (2026-09-25)

The first export, before templates, Editor Settings, and the ETC2 flag, exited 1 with missing `android_debug.apk` / `android_release.apk`, an unset Java SDK path, and an SDK path that had no `platform-tools` or `build-tools`. No APK was produced then.

After those were installed and `import_etc2_astc` was enabled, the debug export in the section above exited 0. Display keys stayed `960` / `720` / `canvas_items` / `expand`. Headless `tests/run_*_tests.gd` all exited 0 (combat 3580, mobile hub 119, touch adapter 86, and the rest of the suite). Release export was not run.

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

## Not done in this environment

- No physical arm64 phone and no emulator, so the APK was not installed or launched here.
- No release APK. Release signing still needs a keystore kept outside the repo.
