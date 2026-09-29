# Live Market Data Stream

How CyberPulse gets live prices, and why the WebSocket path is designed the way
it is.

## The short version

HNICALLS advertises a WebSocket at `wss://api.hnicalls.com/ws/v1`, but that
endpoint **returns 404** — there is no WS server deployed. Probed 29 Sep 2026:

```
$ wss://api.hnicalls.com/ws/v1
The server returned status code '404' when status code '101' was expected.
```

So the app ships two interchangeable transports behind one interface:

1. **`HnicallsWebSocketStream`** — real WebSocket client, reconnect + heartbeat +
   backoff, tolerant of payload shape. It is fully wired and unit-tested, so if
   HNICALLS stands the server up the app starts streaming over it with no code
   change. Point it anywhere with
   `--dart-define=HNICALLS_WS_URL=wss://your-host/ws`.
2. **`HnicallsPollingStream`** — HTTP polling of the endpoints that work today.
   This is what actually delivers data in production today.

`HNICALLS_WS_URL` is **empty by default**, so the app dials no socket and starts
polling on the first frame. Only when you pass the define does the controller
prefer the socket and **fall back to polling automatically** if it fails to
deliver a quote within 6 seconds. The UI never knows or cares which one is
active.

## Architecture

```
  HNICALLS HTTP/WS
         │
         ▼
  MarketStream (interface)          ← lib/services/live/market_stream.dart
    ├── HnicallsWebSocketStream     ← hnicalls_ws_stream.dart
    └── HnicallsPollingStream       ← hnicalls_polling_stream.dart
         │
         ▼
  LiveMarketController (ChangeNotifier)   ← live_market_controller.dart
         │
         ▼
  Watchlist rows (Consumer)
```

`MarketStream` is deliberately tiny:

```dart
abstract class MarketStream {
  String get transportName;
  bool get isSupported;
  Stream<StreamEvent> get events;
  Future<void> start();
  Future<void> stop();
}
```

Each event carries a `StreamStatus` (`idle`, `connecting`, `live`, `degraded`,
`disconnected`, `failed`) and a batch of `LiveQuote`s. Transports are
interchangeable, and the controller takes `MarketStream?` rather than concrete
types so tests inject fakes instead of hitting the network.

## Using it in a widget

The controller is registered in `main.dart`. Read a quote and react to status
changes with a `Consumer`:

```dart
Consumer<LiveMarketController>(
  builder: (context, live, _) {
    final quote = live.quoteFor('NIFTY 22700 CE');
    return Text('${quote?.ltp ?? item.lastPrice}');
  },
)
```

Useful members:

| Member | Purpose |
|---|---|
| `quoteFor(symbol)` | `LiveQuote?` — null until the first tick arrives |
| `status` | Current `StreamStatus` |
| `isLive` | True only on a fully healthy feed |
| `transportName` | `websocket` / `poll` — surfaced in the UI badge |
| `message` | Last error or retry notice, if any |
| `refresh()` | Force one poll cycle (pull-to-refresh, badge tap) |
| `quotes` | Unmodifiable map of every symbol seen |

The Watchlist shows a `LIVE · poll` / `CONNECTING` / `DEGRADED` / `OFFLINE`
chip that reflects this state, and swaps in a live price whenever a matching
quote exists, falling back to the seeded mock price otherwise. A row whose
segment text reads `· live` is showing real data.

## Polling cadence

`HnicallsPollingStream` runs every 15 s and, per cycle:

1. `GET /public/api/ticker_app` — index quotes and movers.
2. `GET /analysis/{instrument}` for each of `NIFTY`, `BANKNIFTY`, `SENSEX`,
   `FINNIFTY` — spot price plus the ATM contract.
3. Optionally (`watchOptionLtp: true`) `GET /option-chain/{instrument}` for the
   ATM row.

Overlapping cycles are skipped, and each request has a timeout (8–20 s). A
failed request increments a failure counter; the cycle still emits whatever it
got. If **nothing** succeeded the event is `degraded` with an empty quote list.
Partial failure yields `degraded` with a message like `2 feed(s) failed` — the
app keeps showing last-known prices rather than blanking.

Endpoints that answer 500 (`/option-chain/*`, `/ltp/*`) are only hit when
explicitly enabled, because polling them every 15 s would burn a lot of requests
for no data.

## Symbol matching

HNICALLS keys quotes on `INSTRUMENT STRIKE TYPE` with no expiry token, while the
app's symbols include one (`NIFTY 24 OCT 22700 CE`). `SymbolParts` bridges the
two:

```dart
SymbolParts.parse('NIFTY 24 OCT 22700 CE').apiSymbol   // 'NIFTY 22700 CE'
SymbolParts.parse('SENSEX 01st OCT 72900 PE').apiSymbol // 'SENSEX 72900 PE'
```

Also available: `apiInstrument` (`NIFTY`), `strikeValue` (`22700`),
`apiOptionType` (`CE`). Futures and cash symbols fall back to the uppercase raw
symbol.

## WebSocket protocol (as documented by HNICALLS)

Not verified — reconstructed from their marketing page, and the client accepts
several shapes so it is not brittle to the exact naming:

- Connect to `wss://api.hnicalls.com/ws/v1`.
- Subscribe: `{"action": "subscribe", "channels": ["ticker", "analysis", "observations"]}`
- Advertised channels: `ticker`, `analysis`, `signals`, `observations`, `system`.
- Expect JSON tick frames; the client reads `quotes` / `data` / `ticker` and
  accepts `symbol`/`tradingsymbol`/`instrument` for the key and
  `ltp`/`last_price`/`premium`/`price` for the value.
- Heartbeat every 20 s: `{"action": "ping", "ts": "<ISO8601>"}`.
- Reconnect with linear backoff from 2 s, capped at 30 s.

If the socket ever delivers a quote, the controller cancels the fallback timer
and stays on the socket for the session.

## If you own the HNICALLS backend

Two changes would let the app go socket-first permanently:

1. Stand up the WS server at `/ws/v1` with the frame names above.
2. Fix the 500s on `/option-chain/{instrument}` and
   `/ltp/{instrument}/{strike}/{type}`.

Then flip `HnicallsPollingStream(watchOptionLtp: true)` on to get per-contract
option premiums, and drop the interval to 5 s if you want faster polling.
