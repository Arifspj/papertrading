# HNICALLS Market Data API

Reference for the endpoints this app calls. All findings were probed live on
**29 Sep 2026** against the production hosts; the reference project
`F:\Recent\hnq` was used to cross-check routes and payload shapes.

## Authentication

**None.** No API key, no bearer token, no cookies, no custom headers. The only
header sent is `Accept: application/json`.

If HNICALLS issues you a key later, pass it at build time and
`HnicallsApiConfig.authHeaders` will attach it automatically:

```powershell
flutter run --dart-define=HNICALLS_API_KEY=your_key
```

## Hosts

| Purpose | Base URL |
|---|---|
| Market data (direct) | `https://api.hnicalls.com/api` |
| Public app feeds | `https://hnicalls.com/api/public/api` |
| WebSocket | `wss://api.hnicalls.com/ws/v1` — **404, see below** |

Both are overridable: `HNICALLS_API_BASE`, `HNICALLS_PUBLIC_BASE`, `HNICALLS_WS_URL`.

## Endpoint status

| Endpoint | Status | Notes |
|---|---|---|
| `GET /analysis/{instrument}` | 200 ✅ | ATM snapshot, PCR, max pain, IV skew |
| `GET /observation/` | 200 ✅ | Free-text feed, list of `{observation}` |
| `GET /public/api/ticker_app` | 200 ✅ | Index quotes + movers |
| `GET /option-chain/{instrument}` | 200 ✅ (market hours) | Every strike's CE/PE LTP in one call |
| `GET /ltp/{instrument}/{strike}/{type}` | 200 ✅ (market hours) | Single contract LTP, used as fallback |
| `wss://api.hnicalls.com/ws/v1` | 404 ❌ | No WS server deployed |

The option routes work **while the market is open** and fail after hours with
`500 {"error": "local variable 'expiry' referenced before assignment"}` — an
upstream bug in how HNICALLS resolves the expiry, not a client mistake. When
that happens the app keeps the last price it had and the row falls back to its
stored value; nothing crashes and the feed reports `degraded`.

Option LTP reaches the UI like this: the watchlist and positions screens call
`LiveMarketController.trackSymbols()` with the rows they are showing. One
`/option-chain/{underlying}` call then resolves every tracked strike of that
underlying, and anything the chain misses falls back to `/ltp/...`. Indices on
those screens come from `ticker_app` and need no tracking.

Both option routes come back and go: the same URL returns 200 for a stretch and
then 500 for minutes at a time, while `ticker_app` keeps working the whole time.
The chain is therefore retried once per cycle, which recovers a good share of
the blips. During a full outage the watchlist and positions still show index
LTP, option rows fall back to their stored price, and the status chip reads
`DEGRADED` — so "no live option LTP" is a real upstream outage, not a wiring
bug.

## Gotchas

- **Case matters.** `/analysis/NIFTY` works; `/option-chain/NIFTY` fails while
  `/option-chain/nifty` is the documented route.
- **No date-based expiry selection.** The only selector is `?type=monthly`.
  Omit it for the nearest weekly expiry.
- **Monthly LTP lives on a different path**, not a query param:
  `/ltp/{instrument}/monthly/{strike}/{CE|PE}`.

## `GET /analysis/{instrument}`

Optional `?type=monthly`.

```json
{
  "status": "success",
  "instrument": "NIFTY",
  "analyzedAt": "2026-09-29T13:39:43.176982",
  "expiryDate": "2026-09-29",
  "spotPrice": 22716.2,
  "strike": 22700,
  "premium": 340.74,
  "option_type": "NEUTRAL",
  "observation": "NIFTY 22700 ATM LTP Rs.340.74 [ATM]",
  "lot_size": 65,
  "pcr": 0.95,
  "max_pain": 22700,
  "iv_skew": -0.08,
  "support": [22250, 21800],
  "resistance": [23150, 23600],
  "sentiment": "NEUTRAL",
  "confidence": "LOW",
  "score": -5,
  "oi_signal": "Bearish",
  "call_oi_chg": 0,
  "put_oi_chg": 0,
  "factors": [],
  "source": "fallback_api"
}
```

Parsed by `OptionAnalysis`. Other fields the model tolerates when present:
`pcr_change`, `pcr_stage`, `pcr_action`, `pcr_sentiment`, `total_call_oi`,
`total_put_oi`, `delta`, `gamma`, `theta`, `vega`, `expiryType`.

`option_type` is `CALL` / `PUT` / `NEUTRAL`. `NEUTRAL` means "ATM, no
directional lean" and maps to **no** `CE`/`PE` suffix.

## `GET /option-chain/{instrument}`

Lowercase instrument, optional `?type=monthly`. Returns `data` either as a bare
list or wrapped in a map; both parse. Rows are sorted by strike on parse.

```json
{
  "status": "success",
  "spot_price": 22716.2,
  "expiry": "2026-09-29",
  "data": [
    {
      "STRIKE": 22700,
      "CALL_LTP": 340.74, "PUT_LTP": 340.74,
      "CALL_OI": 210000,  "PUT_OI": 199500,
      "CALL_OI_CHG": 0,   "PUT_OI_CHG": 0,
      "CALL_IV": 14.0,    "PUT_IV": 14.0,
      "CALL_DELTA": 0.5,  "PUT_DELTA": -0.5,
      "CALL_GAMMA": 0.0,  "PUT_GAMMA": 0.0,
      "CALL_THETA": -6.0, "PUT_THETA": 6.0,
      "CALL_VEGA": 1.0,   "PUT_VEGA": 1.0,
      "CALL_VOL": 0,      "PUT_VOL": 0
    }
  ]
}
```

Volume comes back as `CALL_VOL` / `PUT_VOL` (not `CALL_VOLUME`), which is what
`OptionChainRow` reads.

Derived in `OptionChain`: `atmRow` (nearest strike to spot), `maxPainRow`
(smallest `|callOi − putOi|`), `pcr` (`ΣputOi / ΣcallOi`), `ivSkew` (ATM put IV
− call IV), `ltpFor(strike, isCall:)`.

## `GET /ltp/{instrument}/{strike}/{CE|PE}`

Weekly form above; monthly form is `/ltp/{instrument}/monthly/{strike}/{CE|PE}`.
Accepts `ltp`, `premium` or `LTP` as the value key.

## `GET /observation/`

```json
[{"observation": "NIFTY 22700 ATM LTP Rs.340.74 [ATM]"},
 {"observation": "SENSEX 72500 ATM LTP Rs.1087.94 [ATM]"}]
```

Free text — useful for display, but structured endpoints are preferred for
anything you compute on. `/public/api/obs` returns the same shape.

## `GET /public/api/ticker_app`

```json
{
  "status": "success",
  "updated": "2026-09-29T13:33:37.143Z",
  "smallList": [
    {"symbol": "NIFTY", "ltp": 22716.2, "pct_change": -0.28,
     "prev_close": 22780.25, "open": 22732.45, "high": 22753.25, "low": 22569.65}
  ],
  "moversList": [
    {"symbol": "MANKIND", "ltp": 2549.9, "pct_change": 4.69, "prev_close": 2995}
  ]
}
```

`smallList` = index quotes, `moversList` = top gainers/losers. `change` is
derived as `ltp − prev_close`. This is the endpoint the live stream relies on
most.

## Other public endpoints

| Endpoint | Returns |
|---|---|
| `/public/api/obs` | Same text feed as `/observation/` |
| `/public/api/btst` | Buy-tomorrow short-term calls |
| `/public/api/future` | Futures calls |
| `/public/api/multibagger` | Stock picks |
| `/public/api/ipos` | IPO tracker |

Not yet used by the app; wired up in `HnicallsClient` and ready to surface.
