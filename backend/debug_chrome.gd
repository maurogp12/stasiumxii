extends RefCounted
class_name DebugChrome

## Dev overlays (F3 tile labels, F9 VFX beats, the Stasis provisional sentence).
## OFF unless this project setting is explicitly true. A debug APK is still a
## debug build, so OS.is_debug_build() is not the gate.

const OVERLAY_SETTING := "stasium/debug/dev_overlays"


static func overlays_enabled() -> bool:
	return bool(ProjectSettings.get_setting(OVERLAY_SETTING, false))
