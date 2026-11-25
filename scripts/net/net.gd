extends Node
## Duo vigils: relay connection, lobby and every message exchanged during a game.
## Lives at /root/Net on both machines (created by Game, reachable as Game.net), so all RPCs are
## declared here; game messages are handed to the running survival director:
##   director.net_event(from_peer, kind, args)       reliable, ordered
##   director.net_stream(from_peer, kind, bytes)     frequent state (player pose, enemy snapshots)

signal lobby_changed
signal status(text: String, is_error: bool)

const RelayPeer := preload("res://scripts/net/relay_peer.gd")
## The production relay (server/relay, Cloudflare Workers). Tests and local runs override it
## with the launch flag  relay=ws://127.0.0.1:8791
const RELAY_URL := "wss://dreadhold-relay.CHANGE_ME.workers.dev"
const MAX_NAME := 16

var peer: RelayPeer = null
var room_code := ""
var my_class := "warrior"
var map_id := "keep"
## peer id -> {"name": String, "class": String}, including this machine
var players := {}
var in_game := false
var director: Node = null
var _backlog: Array = []
var _closing_reason := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if Game.test.has("duo"):
		_auto_test.call_deferred()


# ======================================================================= state

func duo() -> bool:
	## True during a duo game (even if the ally has left since).
	return in_game and peer != null


func connected() -> bool:
	return peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func is_host() -> bool:
	return peer != null and peer.is_hosting()


func my_id() -> int:
	return multiplayer.get_unique_id() if peer != null else 1


func partner_id() -> int:
	for id in players:
		if int(id) != my_id():
			return int(id)
	return 0


func partner() -> Dictionary:
	return players.get(partner_id(), {})


func my_name() -> String:
	var n := str(Game.settings.get("player_name", "")).strip_edges()
	return n.substr(0, MAX_NAME) if n != "" else "Champion"


func relay_url() -> String:
	return str(Game.test.get("relay", RELAY_URL)).trim_suffix("/")


# ======================================================================= lobby

func host(cls: String, map: String, code: String = "") -> void:
	leave()
	my_class = cls
	map_id = map
	_open(relay_url() + "/host" + (("?code=" + code) if code != "" else ""), true)


func join(code: String, cls: String) -> void:
	leave()
	my_class = cls
	var c := code.strip_edges().to_upper()
	if c.length() != 4:
		status.emit("A vigil code has four letters", true)
		return
	_open(relay_url() + "/join/" + c, false)


func _open(url: String, as_host: bool) -> void:
	var p: RelayPeer = RelayPeer.new()
	p.relay_message.connect(_on_relay)
	if p.start(url, as_host) != OK:
		status.emit("Cannot reach the relay", true)
		return
	peer = p
	multiplayer.multiplayer_peer = p
	players = {}
	_closing_reason = ""
	status.emit("Calling the relay...", false)


func set_map(map: String) -> void:
	map_id = map
	if is_host() and connected():
		_lobby.rpc(map_id)
	lobby_changed.emit()


func can_start() -> bool:
	return is_host() and connected() and players.size() >= 2


func start_game() -> void:
	if can_start():
		_begin.rpc(map_id)


func leave() -> void:
	## Leave the room (and the game). Safe to call at any time.
	in_game = false
	director = null
	_backlog.clear()
	if peer != null:
		var p: RelayPeer = peer
		peer = null
		p.close()
		multiplayer.multiplayer_peer = null
	players = {}
	room_code = ""
	lobby_changed.emit()


func _on_relay(msg: Dictionary) -> void:
	if Game.test.has("log"):
		print("[net] relay says ", msg)
	match str(msg.get("op", "")):
		"hosted":
			room_code = str(msg.get("code", ""))
			players[1] = {"name": my_name(), "class": my_class}
			status.emit("Give this code to your ally", false)
			lobby_changed.emit()
		"joined":
			room_code = str(msg.get("code", ""))
			players[int(msg.get("id", 2))] = {"name": my_name(), "class": my_class}
			status.emit("Joined the vigil - waiting for the host", false)
			lobby_changed.emit()
		"error":
			var why := str(msg.get("reason", ""))
			_closing_reason = "This vigil already has two champions" if why == "full" else "No vigil is waiting with this code"
		"closed":
			_closing_reason = "The host has ended the vigil"
		"disconnected":
			var reason := _closing_reason
			match int(msg.get("code", 0)):
				4001:
					reason = "The host has ended the vigil"
				4004:
					reason = "No vigil is waiting with this code"
				4009:
					reason = "This vigil already has two champions"
			if reason == "":
				reason = "Lost the connection to the relay" if bool(msg.get("reached", false)) else "Cannot reach the relay"
			var d := director
			_cleanup.call_deferred()
			if d != null and is_instance_valid(d):
				d.net_lost(reason)
			status.emit(reason, true)


func _cleanup() -> void:
	## Deferred: never swap the multiplayer peer while it is being polled.
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		peer = null
		multiplayer.multiplayer_peer = null
		players = {}
		room_code = ""
		in_game = false
		director = null
		lobby_changed.emit()


func _on_peer_connected(id: int) -> void:
	_hello.rpc_id(id, my_name(), my_class)
	if is_host():
		_lobby.rpc_id(id, map_id)


func _on_peer_disconnected(id: int) -> void:
	var who: Dictionary = players.get(id, {})
	players.erase(id)
	lobby_changed.emit()
	if id == 1 and not is_host():
		return  # the host left: the relay closes the room, handled in _on_relay("disconnected")
	if director != null and is_instance_valid(director):
		director.net_partner_left(str(who.get("name", "Your ally")))
	elif peer != null and id != 1:
		status.emit("%s left the vigil" % str(who.get("name", "Your ally")), false)


@rpc("any_peer", "reliable")
func _hello(p_name: String, p_class: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	players[id] = {"name": p_name.substr(0, MAX_NAME), "class": p_class}
	status.emit("%s joined the vigil" % p_name if is_host() else "Waiting for the host to begin", false)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _lobby(map: String) -> void:
	map_id = map
	lobby_changed.emit()


@rpc("authority", "call_local", "reliable")
func _begin(map: String) -> void:
	map_id = map
	in_game = true
	_backlog.clear()
	Game.selected_map = map
	Game.selected_class = my_class
	Game.pending_save = {}
	Game.goto(Game.SCENE_SURVIVAL)


# ======================================================================= in-game messages

func attach(d: Node) -> void:
	## The survival director is ready: deliver what arrived while the scene was loading.
	director = d
	var pending := _backlog
	_backlog = []
	for e in pending:
		d.net_event(int(e[0]), str(e[1]), e[2])


func send(kind: String, args: Array = []) -> void:
	if duo() and connected() and players.size() >= 2:
		_ev.rpc(kind, args)


func send_to(id: int, kind: String, args: Array = []) -> void:
	if duo() and connected() and players.has(id):
		_ev.rpc_id(id, kind, args)


func stream(kind: String, data: PackedByteArray) -> void:
	if duo() and connected() and players.size() >= 2:
		_st.rpc(kind, data)


@rpc("any_peer", "reliable")
func _ev(kind: String, args: Array) -> void:
	var from := multiplayer.get_remote_sender_id()
	if director != null and is_instance_valid(director):
		director.net_event(from, kind, args)
	elif in_game:
		_backlog.append([from, kind, args])


@rpc("any_peer", "unreliable_ordered")
func _st(kind: String, data: PackedByteArray) -> void:
	if director != null and is_instance_valid(director):
		director.net_stream(multiplayer.get_remote_sender_id(), kind, data)


# ======================================================================= test harness

func _auto_test() -> void:
	## duo=host|join [code=ABCD] [relay=ws://...] [autostart]: skip the lobby screens.
	var cls := Game.selected_class
	if Game.test["duo"] == "host":
		host(cls, Game.selected_map, str(Game.test.get("code", "")))
		if Game.test.has("autostart"):
			lobby_changed.connect(func():
				if can_start() and not in_game:
					start_game.call_deferred())
	else:
		join(str(Game.test.get("code", "TEST")), cls)
