# STASIUM XII mobile debug keystore

This directory holds the **debug-only** Android signing key for sideload cuts of `com.maurogp12.stasiumxii.mobile`. It is not a Play App Signing key and it is not a release key. Do not use it for a Play upload.

## Why it is in git

With empty `keystore/debug*` fields, Godot mints a new debug certificate on each machine (`~/.local/share/godot/keystores/debug.keystore`). The 0.1.9, 0.1.10, and 0.1.11 sideload APKs were signed with different certs, so each install required an uninstall. This keystore is the one shared cert for later debug sideload builds. The file lives here, not under `/android/`, because `.gitignore` ignores `/android/`.

## Identity

| Field | Value |
| --- | --- |
| File | `build_tools/mobile/stasiumxii-mobile-debug.keystore` |
| Godot path | `res://build_tools/mobile/stasiumxii-mobile-debug.keystore` |
| Alias (`keystore/debug_user`) | `stasiumxii_mobile_debug` |
| Store password (`keystore/debug_password`) | `stasiumxii-mobile-debug` |
| Key password | `stasiumxii-mobile-debug` (same as the store password) |
| Distinguished name | `CN=STASIUM XII Mobile Debug, OU=STASIUM XII, O=maurogp12, C=US` |
| Key | RSA 2048, PKCS12 store |
| Validity | 10000 days, 2026-09-25 through 2054-02-10 |

Regenerating this file creates a new cert. That forces another uninstall on every phone that already has a build signed with the fingerprint below. Keep this file.

## Certificate SHA-256

Public certificate SHA-256, lowercase hex (no colons):

```text
3725b12ee58cf1d911c373bc5ef0b6be3c47afb41421777f2b505bb4aa6063e2
```

The same digest as `keytool -list -v` prints it (colon form):

```text
37:25:B1:2E:E5:8C:F1:D9:11:C3:73:BC:5E:F0:B6:BE:3C:47:AF:B4:14:21:77:7F:2B:50:5B:B4:AA:60:63:E2
```

From this checkout:

```text
build_tools/mobile/print_debug_cert_sha256.sh
```

That script prints the lowercase hex line. `keytool -list -v -keystore build_tools/mobile/stasiumxii-mobile-debug.keystore -alias stasiumxii_mobile_debug -storepass stasiumxii-mobile-debug` prints the colon form under `SHA256:`.

The next content cut should report this same SHA-256. A different value means the export did not use this keystore.

## How cloud cuts must use it

`export_presets.cfg` already points the Android preset at this file:

- `keystore/debug` = `res://build_tools/mobile/stasiumxii-mobile-debug.keystore`
- `keystore/debug_user` = `stasiumxii_mobile_debug`
- `keystore/debug_password` = `stasiumxii-mobile-debug`

A debug export (`godot --headless --path . --export-debug "Android" …`) signs with this cert. Godot 4.7 resolves the `res://` path from the project root, then passes that file to `keytool` / `apksigner`. Leave those three fields as committed. Do not set `GODOT_ANDROID_KEYSTORE_DEBUG_PATH`, `GODOT_ANDROID_KEYSTORE_DEBUG_USER`, or `GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD`. Godot prefers those variables over the preset, and that is how a fresh `~/.local/share/godot/keystores/debug.keystore` replaced the cert on each cut.

Godot 4.7 marks the debug keystore path, user, and password as secret export options. A headless export reads them from `export_presets.cfg` when `.godot/export_credentials.cfg` is absent. An editor save moves those three values into `.godot/export_credentials.cfg` (gitignored) and drops them from `export_presets.cfg`. If that happens, put the three lines back before committing. Do not commit `export_credentials.cfg`, and do not leave a credentials file that overrides these fields with empty strings. Empty debug fields make Godot fall back to the per-machine editor debug keystore.

Phones that already have a pre-pin APK (0.1.9, 0.1.10, or 0.1.11) still need one uninstall before the first build signed with this cert. After that, later debug builds that report this SHA-256 can install as upgrades.

## Release signing is separate

`keystore/release`, `keystore/release_user`, and `keystore/release_password` stay empty. Do not commit a release keystore or Play App Signing material. Release signing stays outside this repo.
