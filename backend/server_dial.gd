extends RefCounted
class_name ServerDial

## Address chain for Play Online. The last address that connected is tried
## first. Then the public server, the Tailscale address (the dedicated host
## sits on another house's network), then the LAN address. Each probe is
## short so the whole chain stays under about 12 seconds.

const PUBLIC_ADDRESS := "68.201.184.207"
const TAILSCALE_ADDRESS := "100.94.184.28"
const LAN_ADDRESS := "192.168.1.58"
const PORT := 7777
const PROBE_SEC := 2.5
const SAVE_PATH := "user://online_server.cfg"


static func fallback_hosts() -> Array[String]:
	return [PUBLIC_ADDRESS, TAILSCALE_ADDRESS, LAN_ADDRESS]


static func address_order(remembered: String = "") -> Array[String]:
	var order: Array[String] = []
	var head := remembered.strip_edges()
	if head != "":
		order.append(head)
	for host in fallback_hosts():
		if not order.has(host):
			order.append(host)
	return order


static func chain_seconds(remembered: String = "") -> float:
	return float(address_order(remembered).size()) * PROBE_SEC


static func remembered(path: String = SAVE_PATH) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return ""
	return str(cfg.get_value("dial", "address", "")).strip_edges()


static func remember(address: String, path: String = SAVE_PATH) -> void:
	var cleaned := address.strip_edges()
	if cleaned == "":
		return
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("dial", "address", cleaned)
	cfg.save(path)


static func forget(path: String = SAVE_PATH) -> void:
	if not FileAccess.file_exists(path):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
