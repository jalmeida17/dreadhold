// Smoke test for the relay: host a room, join it, exchange packets both ways, check leave events.
// usage: node test/smoke.mjs [ws://127.0.0.1:8787]
const base = process.argv[2] || "ws://127.0.0.1:8787";

function open(url) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    ws.binaryType = "arraybuffer";
    const inbox = [];
    const waiters = [];
    ws.onmessage = (ev) => {
      const msg = typeof ev.data === "string" ? JSON.parse(ev.data) : new Uint8Array(ev.data);
      const w = waiters.shift();
      if (w) w(msg);
      else inbox.push(msg);
    };
    ws.onopen = () => resolve({
      ws,
      next: () => new Promise((r) => (inbox.length ? r(inbox.shift()) : waiters.push(r))),
    });
    ws.onerror = reject;
  });
}

function packet(target, bytes) {
  const out = new Uint8Array(4 + bytes.length);
  new DataView(out.buffer).setInt32(0, target, true);
  out.set(bytes, 4);
  return out;
}

function check(cond, what) {
  if (!cond) {
    console.error("FAIL:", what);
    process.exit(1);
  }
  console.log("ok  ", what);
}

const host = await open(`${base}/host`);
const hosted = await host.next();
check(hosted.op === "hosted" && hosted.id === 1 && /^[A-Z]{4}$/.test(hosted.code), `hosted room ${hosted.code}`);

const ally = await open(`${base}/join/${hosted.code.toLowerCase()}`);
const joined = await ally.next();
check(joined.op === "joined" && joined.id === 2 && joined.peers.includes(1), "ally joined as peer 2");
const seen = await host.next();
check(seen.op === "peer_joined" && seen.id === 2, "host told about the ally");

ally.ws.send(packet(1, new Uint8Array([7, 8, 9])));
const toHost = await host.next();
check(new DataView(toHost.buffer).getInt32(0, true) === 2 && toHost[4] === 7 && toHost.length === 7, "ally -> host packet, source rewritten");

host.ws.send(packet(0, new Uint8Array([1, 2])));
const toAlly = await ally.next();
check(new DataView(toAlly.buffer).getInt32(0, true) === 1 && toAlly[5] === 2, "host broadcast reaches the ally");

const third = await open(`${base}/join/${hosted.code}`);
const refused = await third.next();
check(refused.op === "error" && refused.reason === "full", "third player refused (room full)");

const ghost = await open(`${base}/join/ZZZZ`);
const nf = await ghost.next();
check(nf.op === "error" && nf.reason === "not_found", "unknown code refused");

ally.ws.close();
const left = await host.next();
check(left.op === "peer_left" && left.id === 2, "host told when the ally leaves");

const ally2 = await open(`${base}/join/${hosted.code}`);
await ally2.next();
await host.next();
host.ws.close();
const closed = await ally2.next();
check(closed.op === "closed", "ally told when the host closes the room");
console.log("relay smoke test passed");
process.exit(0);
