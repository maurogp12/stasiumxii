extends RefCounted

## Where the launcher looks for updates. This is the one line to change when
## hosting moves (Cloudflare R2, a CDN...). Chunk urls in the manifest are
## relative to it. A launcher_config.json next to the exe with
## {"manifest_url": "..."} or the --manifest-url=... argument overrides it.
const MANIFEST_URL := "https://raw.githubusercontent.com/maurogp12/stasiumxii/pc-builds/launcher/latest.json"

## The scene Play opens.
const GAME_SCENE := "res://scenes/world/crosshaven/crosshaven_world.tscn"
