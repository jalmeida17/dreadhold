extends MultiplayerPeerExtension
## MultiplayerPeer over a single WebSocket to the Dreadhold relay (server/relay).
## Works the same in the browser and in the desktop app, and needs no port forwarding:
## the relay forwards every packet between the players of a room.
##   text frames from the relay: JSON control messages (hosted, joined, peer_joined, peer_left,
##                               closed, error) -> re-emitted as `relay_message`
##   binary frames: [int32 LE peer][payload]  (target when sending, source when receiving)

signal relay_message(msg: Dictionary)

var ws := WebSocketPeer.new()
var _id := 0
var _status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _host := false
var _target := 0
var _incoming: Array = []   # [from_id, PackedByteArray]
var _peers := {}
var _mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _channel := 0
var _refusing := false
var _ever_open := false


func start(url: String, as_host: bool) -> Error:
	_host = as_host
	ws.inbound_buffer_size = 1 << 20
	ws.outbound_buffer_size = 1 << 20
	ws.max_queued_packets = 8192
	var err := ws.connect_to_url(url)
	if err == OK:
		_status = MultiplayerPeer.CONNECTION_CONNECTING
	return err


func is_hosting() -> bool:
	return _host


func _poll() -> void:
	ws.poll()
	var state := ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_ever_open = true
	# drain first: the relay's last words ("closed", "error") arrive just before the socket shuts
	while ws.get_available_packet_count() > 0:
		var pkt := ws.get_packet()
		if ws.was_string_packet():
			_on_control(pkt.get_string_from_utf8())
		elif pkt.size() >= 4:
			_incoming.append([pkt.decode_s32(0), pkt.slice(4)])
	match state:
		WebSocketPeer.STATE_CLOSED:
			if _status != MultiplayerPeer.CONNECTION_DISCONNECTED:
				var was := _status
				_drop_peers()
				_status = MultiplayerPeer.CONNECTION_DISCONNECTED
				relay_message.emit({"op": "disconnected", "was_connected": was == MultiplayerPeer.CONNECTION_CONNECTED,
					"reached": _ever_open, "code": ws.get_close_code()})


func _on_control(text: String) -> void:
	var msg = JSON.parse_string(text)
	if typeof(msg) != TYPE_DICTIONARY:
		return
	match str(msg.get("op", "")):
		"hosted":
			_id = 1
			_status = MultiplayerPeer.CONNECTION_CONNECTED
		"joined":
			_id = int(msg.get("id", 0))
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			for p in msg.get("peers", []):
				_add_peer(int(p))
		"peer_joined":
			_add_peer(int(msg.get("id", 0)))
		"peer_left":
			_remove_peer(int(msg.get("id", 0)))
		"closed":
			_drop_peers()
	relay_message.emit(msg)


func _add_peer(id: int) -> void:
	if id <= 0 or _peers.has(id):
		return
	_peers[id] = true
	peer_connected.emit(id)


func _remove_peer(id: int) -> void:
	if _peers.erase(id):
		peer_disconnected.emit(id)


func _drop_peers() -> void:
	for id in _peers.keys():
		_remove_peer(int(id))


# ---------------------------------------------------------------- MultiplayerPeer interface

func _get_available_packet_count() -> int:
	return _incoming.size()


func _get_packet_script() -> PackedByteArray:
	if _incoming.is_empty():
		return PackedByteArray()
	var p: Array = _incoming.pop_front()
	return p[1]


func _get_packet_peer() -> int:
	return int(_incoming[0][0]) if not _incoming.is_empty() else 0


func _get_packet_channel() -> int:
	return 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return MultiplayerPeer.TRANSFER_MODE_RELIABLE


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNCONFIGURED
	var out := PackedByteArray()
	out.resize(4)
	out.encode_s32(0, _target)
	out.append_array(buffer)
	return ws.put_packet(out)


func _get_max_packet_size() -> int:
	return 1 << 20


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _set_target_peer(peer: int) -> void:
	_target = peer


func _is_server() -> bool:
	return _host


func _get_unique_id() -> int:
	return _id


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _close() -> void:
	ws.close()
	_drop_peers()
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED


func _disconnect_peer(peer: int, _force: bool) -> void:
	_remove_peer(peer)


func _set_refuse_new_connections(enable: bool) -> void:
	_refusing = enable


func _is_refusing_new_connections() -> bool:
	return _refusing


func _is_server_relay_supported() -> bool:
	return false
