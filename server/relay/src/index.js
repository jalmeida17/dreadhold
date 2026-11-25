// Dreadhold duo relay.
//
// One Durable Object per room code. The host opens  wss://<relay>/host  and receives a code;
// its ally opens  wss://<relay>/join/<CODE>. After that the relay only forwards packets:
//
//   text frames  (JSON, relay -> client): hosted, joined, peer_joined, peer_left, closed, error
//   binary frames (client -> relay): [int32 LE target][payload]   target 0 = every other peer,
//                                                                  target > 0 = that peer,
//                                                                  target < 0 = all but -target
//   binary frames (relay -> client): [int32 LE source][payload]
//
// The host is always peer 1 (Godot's server id); allies get 2, 3, ... The room closes with its host.
// Refusals and endings also travel in the close code, which survives when the last text frame
// does not: 4001 host left, 4004 no such room, 4009 room full.

import { DurableObject } from "cloudflare:workers";

const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ"; // no I or O: codes are read aloud
const MAX_PLAYERS = 2;

function randomCode() {
  const bytes = new Uint8Array(4);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => CODE_CHARS[b % CODE_CHARS.length]).join("");
}

function roomStub(env, code) {
  return env.ROOMS.get(env.ROOMS.idFromName(code));
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.headers.get("Upgrade") !== "websocket") {
      if (url.pathname === "/" || url.pathname === "/health") {
        return new Response("dreadhold relay ok\n", { headers: { "content-type": "text/plain" } });
      }
      return new Response("expected a websocket\n", { status: 426 });
    }
    if (url.pathname === "/host") {
      // a fixed code can be asked for (handy for tests); otherwise draw until a free one is found
      const wanted = (url.searchParams.get("code") || "").toUpperCase();
      for (let attempt = 0; attempt < 8; attempt++) {
        const code = attempt === 0 && /^[A-Z]{4}$/.test(wanted) ? wanted : randomCode();
        const res = await roomStub(env, code).fetch(new Request(`https://room/host?code=${code}`, request));
        if (res.status !== 409) return res;
      }
      return new Response("no free room\n", { status: 503 });
    }
    const join = url.pathname.match(/^\/join\/([A-Za-z]{4})$/);
    if (join) {
      const code = join[1].toUpperCase();
      return roomStub(env, code).fetch(new Request(`https://room/join?code=${code}`, request));
    }
    return new Response("not found\n", { status: 404 });
  },
};

export class Room extends DurableObject {
  _peers() {
    // [{ ws, id }] for every open socket of this room (survives hibernation through attachments)
    const out = [];
    for (const ws of this.ctx.getWebSockets()) {
      const a = ws.deserializeAttachment();
      if (a && a.id) out.push({ ws, id: a.id });
    }
    return out;
  }

  _accept(id, code) {
    const pair = new WebSocketPair();
    this.ctx.acceptWebSocket(pair[1]);
    if (id) pair[1].serializeAttachment({ id, code });
    return pair;
  }

  async fetch(request) {
    const url = new URL(request.url);
    const code = url.searchParams.get("code");
    const peers = this._peers();
    const host = peers.find((p) => p.id === 1);

    if (url.pathname === "/host") {
      if (host) return new Response("taken", { status: 409 });
      const pair = this._accept(1, code);
      pair[1].send(JSON.stringify({ op: "hosted", code, id: 1 }));
      return new Response(null, { status: 101, webSocket: pair[0] });
    }

    // join: always upgrade, so the client gets a readable reason when it is refused
    if (!host || peers.length >= MAX_PLAYERS) {
      const pair = this._accept(0, code);
      pair[1].send(JSON.stringify({ op: "error", reason: host ? "full" : "not_found" }));
      pair[1].close(host ? 4009 : 4004, host ? "room full" : "room not found");
      return new Response(null, { status: 101, webSocket: pair[0] });
    }
    const used = new Set(peers.map((p) => p.id));
    let id = 2;
    while (used.has(id)) id++;
    const pair = this._accept(id, code);
    pair[1].send(JSON.stringify({ op: "joined", code, id, peers: peers.map((p) => p.id) }));
    for (const p of peers) p.ws.send(JSON.stringify({ op: "peer_joined", id }));
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  async webSocketMessage(ws, message) {
    const from = ws.deserializeAttachment();
    if (!from || !from.id) return;
    if (typeof message === "string") {
      if (message === "ping") ws.send("pong");
      return;
    }
    if (message.byteLength < 4) return;
    const view = new DataView(message);
    const target = view.getInt32(0, true);
    const out = new Uint8Array(message.byteLength);
    out.set(new Uint8Array(message));
    new DataView(out.buffer).setInt32(0, from.id, true);
    for (const p of this._peers()) {
      if (p.id === from.id) continue;
      if (target > 0 && p.id !== target) continue;
      if (target < 0 && p.id === -target) continue;
      try {
        p.ws.send(out);
      } catch (_) {
        // the socket is closing; its close handler tells the others
      }
    }
  }

  async webSocketClose(ws, code, reason) {
    this._left(ws);
    try {
      ws.close(code === 1005 ? 1000 : code, reason);
    } catch (_) {}
  }

  async webSocketError(ws) {
    this._left(ws);
  }

  _left(ws) {
    const a = ws.deserializeAttachment();
    if (!a || !a.id) return;
    ws.serializeAttachment(null);
    for (const p of this._peers()) {
      if (p.ws === ws) continue;
      try {
        if (a.id === 1) {
          // the host left: the vigil is over for everyone
          p.ws.send(JSON.stringify({ op: "closed" }));
          p.ws.close(4001, "host left");
        } else {
          p.ws.send(JSON.stringify({ op: "peer_left", id: a.id }));
        }
      } catch (_) {}
    }
  }
}
