extends RefCounted

## Baked mobile export stamp. The only numbers Actualizar may use when
## PackageManager cannot read the installed APK.
##
## Must match export_presets.cfg `version/name` and `version/code` for the
## Android preset (same stamp the release notes print as `0.1.N-mobile`
## and `(code N)`). Export bump agents update this file in the same change
## as the preset. Do not invent a different number.
##
## Headless tests compare the two. A preset bump that forgets this file fails.

const VERSION_NAME := "0.1.22-mobile"
const VERSION_CODE := 23
