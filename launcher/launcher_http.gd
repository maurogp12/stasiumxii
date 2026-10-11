extends RefCounted

## Blocking HTTP(S) client for the launcher's worker thread.
## Follows redirects, resumes with Range, and gives up after a stall.

const USER_AGENT := "StasiumXII-Launcher/1"
const MAX_REDIRECTS := 6

## Seconds with no bytes before a request is dropped.
var stall_timeout := 30.0
## Set to true from another thread to stop the current transfer.
var cancelled := false


## GET a small text body. Returns {ok, code, body, error}.
func fetch_text(url: String) -> Dictionary:
	var parts: Array = []
	var total := [0]
	var res := _request(url, 0, func(b: PackedByteArray) -> bool:
		parts.append(b)
		total[0] += b.size()
		return total[0] < 8 * 1024 * 1024, Callable())
	var buf := PackedByteArray()
	for b in parts:
		buf.append_array(b)
	res["body"] = buf.get_string_from_utf8()
	return res


## Downloads url into path. When the file already holds some bytes it asks for
## the rest with Range and appends. progress(delta_bytes) is called as bytes land.
## Returns {ok, code, error, resumed_from, bytes}.
func download_to(url: String, path: String, expected_size: int, progress: Callable = Callable()) -> Dictionary:
	var have := 0
	if FileAccess.file_exists(path):
		var probe := FileAccess.open(path, FileAccess.READ)
		have = int(probe.get_length()) if probe else 0
		probe = null
	if expected_size >= 0 and have > expected_size:
		DirAccess.remove_absolute(path)
		have = 0
	if expected_size >= 0 and have == expected_size:
		return {"ok": true, "code": 0, "error": "", "resumed_from": have, "bytes": 0}
	var f: FileAccess
	if have > 0:
		f = FileAccess.open(path, FileAccess.READ_WRITE)
		f.seek_end()
	else:
		f = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "code": 0, "error": "cannot write %s" % path, "resumed_from": have, "bytes": 0}
	# Lambdas capture locals by value, so the file handle lives in an array.
	var fh: Array = [f]
	var got := [0]
	var restarted := [false]
	var on_head := func(code: int) -> void:
		# The server ignored our Range: start the file over.
		if have > 0 and code == 200:
			fh[0].close()
			fh[0] = FileAccess.open(path, FileAccess.WRITE)
			restarted[0] = true
	var res := _request(url, have, func(b: PackedByteArray) -> bool:
		fh[0].store_buffer(b)
		got[0] += b.size()
		if progress.is_valid():
			progress.call(b.size())
		return true, on_head)
	fh[0].close()
	res["resumed_from"] = 0 if restarted[0] else have
	res["bytes"] = got[0]
	if res["ok"] and int(res["code"]) == 416 and have == expected_size:
		res["ok"] = true
	return res


## Core loop. on_body(bytes) -> bool (false aborts). on_head(code) runs before the body.
func _request(url: String, from_byte: int, on_body: Callable, on_head: Callable) -> Dictionary:
	var current := url
	for _hop in MAX_REDIRECTS:
		var parts := _split_url(current)
		if parts.is_empty():
			return {"ok": false, "code": 0, "error": "bad url %s" % current}
		var client := HTTPClient.new()
		client.read_chunk_size = 256 * 1024
		var tls: TLSOptions = TLSOptions.client() if parts["tls"] else null
		var err := client.connect_to_host(parts["host"], parts["port"], tls)
		if err != OK:
			return {"ok": false, "code": 0, "error": "cannot connect to %s" % parts["host"]}
		var wait := _wait_while(client, [HTTPClient.STATUS_RESOLVING, HTTPClient.STATUS_CONNECTING])
		if wait != "":
			return {"ok": false, "code": 0, "error": wait}
		if client.get_status() != HTTPClient.STATUS_CONNECTED:
			return {"ok": false, "code": 0, "error": "could not connect to %s (status %d)" % [parts["host"], client.get_status()]}
		var headers := PackedStringArray(["User-Agent: " + USER_AGENT, "Accept-Encoding: identity"])
		if from_byte > 0:
			headers.append("Range: bytes=%d-" % from_byte)
		err = client.request(HTTPClient.METHOD_GET, parts["path"], headers)
		if err != OK:
			return {"ok": false, "code": 0, "error": "request failed"}
		wait = _wait_while(client, [HTTPClient.STATUS_REQUESTING])
		if wait != "":
			return {"ok": false, "code": 0, "error": wait}
		if not client.has_response():
			return {"ok": false, "code": 0, "error": "no response (status %d)" % client.get_status()}
		var code := client.get_response_code()
		if code in [301, 302, 303, 307, 308]:
			var loc := ""
			for h in client.get_response_headers():
				if h.to_lower().begins_with("location:"):
					loc = h.substr(9).strip_edges()
			client.close()
			if loc.is_empty():
				return {"ok": false, "code": code, "error": "redirect without location"}
			if loc.begins_with("/"):
				loc = "%s://%s%s" % ["https" if parts["tls"] else "http", parts["hostport"], loc]
			current = loc
			continue
		if code == 416:
			client.close()
			return {"ok": true, "code": code, "error": ""}
		if code != 200 and code != 206:
			client.close()
			return {"ok": false, "code": code, "error": "HTTP %d for %s" % [code, current.get_file()]}
		if on_head.is_valid():
			on_head.call(code)
		var expected := client.get_response_body_length()
		var received := 0
		var idle := 0.0
		var last := Time.get_ticks_msec()
		while client.get_status() == HTTPClient.STATUS_BODY:
			if cancelled:
				client.close()
				return {"ok": false, "code": code, "error": "cancelled"}
			client.poll()
			var chunk := client.read_response_body_chunk()
			var now := Time.get_ticks_msec()
			if chunk.is_empty():
				idle += (now - last) / 1000.0
				last = now
				if idle > stall_timeout:
					client.close()
					return {"ok": false, "code": code, "error": "download stalled"}
				OS.delay_msec(2)
				continue
			idle = 0.0
			last = now
			received += chunk.size()
			if not on_body.call(chunk):
				client.close()
				return {"ok": false, "code": code, "error": "body too large"}
		client.close()
		if expected >= 0 and received < expected:
			return {"ok": false, "code": code, "error": "connection cut after %d of %d bytes" % [received, expected]}
		return {"ok": true, "code": code, "error": ""}
	return {"ok": false, "code": 0, "error": "too many redirects"}


func _wait_while(client: HTTPClient, states: Array) -> String:
	var start := Time.get_ticks_msec()
	while client.get_status() in states:
		if cancelled:
			return "cancelled"
		client.poll()
		OS.delay_msec(5)
		if Time.get_ticks_msec() - start > int(stall_timeout * 1000.0):
			return "timed out"
	var s := client.get_status()
	if s == HTTPClient.STATUS_CANT_RESOLVE:
		return "cannot resolve host"
	if s == HTTPClient.STATUS_CANT_CONNECT:
		return "cannot connect"
	if s == HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
		return "TLS handshake failed"
	if s == HTTPClient.STATUS_CONNECTION_ERROR:
		return "connection error"
	return ""


static func _split_url(url: String) -> Dictionary:
	var tls := false
	var rest := url
	if url.begins_with("https://"):
		tls = true
		rest = url.substr(8)
	elif url.begins_with("http://"):
		rest = url.substr(7)
	else:
		return {}
	var slash := rest.find("/")
	var hostport := rest if slash < 0 else rest.substr(0, slash)
	var path := "/" if slash < 0 else rest.substr(slash)
	var host := hostport
	var port := 443 if tls else 80
	var colon := hostport.rfind(":")
	if colon > 0 and hostport.substr(colon + 1).is_valid_int():
		host = hostport.substr(0, colon)
		port = int(hostport.substr(colon + 1))
	return {"tls": tls, "host": host, "port": port, "path": path, "hostport": hostport}
