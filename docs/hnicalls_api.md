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
| `GET /indices` | 200 ✅ | Index LTP/prev-close, but only NIFTY + SENSEX, and self-reports `"source":"fallback_api"` |
| `GET /observation/` | 200 ✅ | Free-text feed, list of `{observation}` |
| `GET /public/api/ticker_app` | 200 ✅ | Index quotes + movers |
| `GET /option-chain/{instrument}` | Intermittent | Works at times, 500s in bursts |
| `GET /ltp/{instrument}/{strike}/{type}` | 200 ⚠️ | **Works, but PE prices and OI are wrong** |
| `wss://api.hnicalls.com/ws/v1` | 404 ❌ | No WS server deployed |

## The `/ltp` route: use with care

`GET /api/ltp/nifty/22700/pe` used to fail with
`{"error":"local variable 'expiry' referenced before assignment"}` — a Python
`UnboundLocalError`. That is fixed upstream now; the bare route returns 200.

**The `?expiry=` query parameter is a no-op.** Every value returns the same
nearest-expiry row: `?expiry=01-OCT-2026`, `?expiry=2026-10-01`,
`?expiry=anything` and even `?expiry=` all return `"expiry":"2026-09-29"`. There
is no way to select an expiry; you get whatever the server resolves.

The payload is richer than the chain:

```json
{"expiry":"2026-09-29","expiry_type":"weekly","instrument":"NIFTY",
 "ltp":16.25,"oi":16266510.0,"option_type":"CE","status":"success","strike":22700}
```

Note the resolved `expiry` is **per-underlying**: NIFTY returned `2026-09-29`
while SENSEX returned `2026-10-01` for the same call shape.

### But the numbers are not trustworthy

Measured across a strike ladder with spot at 22716.2:

| Strike | CE ltp | CE oi | PE ltp | PE oi |
|---|---|---|---|---|
| 22000 | 717.65 | 224,185 | 0.05 | 11,602,630 |
| 22500 | 215.75 | 1,522,820 | 0.05 | 9,579,050 |
| 22700 | 16.25 | 16,266,510 | 0.05 | 20,374,835 |
| 23000 | 0.05 | 10,555,415 | 283.3 | 3,197,010 |
| 23500 | 0.05 | 12,625,990 | 784 | 2,391,935 |

- **CE ladder is sound** — it decays monotonically, which is what an option
  ladder must do.
- **PE ladder is broken.** A 22700 PE with spot at 22716 is in the money by
  ~16, so it cannot be worth 0.05. And a 23000 PE is ~284 points out of the
  money, so it cannot be worth 283.3. Both ends are impossible.
- **`oi` is meaningless.** Real NIFTY open interest peaks at the money and falls
  off hard at the wings; here 22000 CE carries 224k while 22000 PE carries
  11.6 million, and the ATM carries 16 million. These are not real OI numbers.

Treating a 0.05 price as real is a much worse failure than showing nothing: on a
16-point in-the-money position it reads as a 99% loss. The option chain remains
the only source trusted for option prices.

## Why the chain also 500s

`/option-chain/{instrument}` fails with
`{"error":"Failed to fetch option chain from Upstox","message":"Could not retrieve option chain data"}`.

It is genuinely intermittent: the same URL returned 200 with 144 strikes during
this audit and then failed 6 times in a row minutes later, while `ticker_app`
stayed healthy the whole time. One contributing factor is that
`/analysis/{instrument}` currently reports `expiryDate: "2026-09-29"` — today's
date, which is a Tuesday and therefore NIFTY's weekly expiry day. Once that
session is over, Upstox may stop serving a chain for the expired contract. This
is the most likely reason, but it is not proven: the 200 response shows the
route can still serve the just-closed expiry.

The chain is retried once per cycle to ride out the blips. During a full outage
the watchlist and positions still show index LTP, option rows fall back to their
stored price, and the status chip reads `DEGRADED`.

## Gotchas

- **Case does not matter.** An earlier note in this file claimed
  `/option-chain/NIFTY` failed while `/option-chain/nifty` worked. That was
  wrong — it was an assumption, not a measurement. Probed both: `/analysis/nifty`
  and `/analysis/NIFTY` return byte-identical JSON, and `/option-chain/nifty` and
  `/option-chain/NIFTY` return byte-identical errors. The client sends lowercase
  because that matches the documented route, not because upper-case breaks.
- **No date-based expiry selection.** The only selector is `?type=monthly`, and
  omitting it gives the nearest weekly expiry. No route accepts an explicit
  expiry date, which is what makes the `/ltp` breakage unrecoverable client-side.
- **Monthly LTP was documented as a separate path**, `/ltp/{instrument}/monthly/
  {strike}/{CE|PE}`. That path also returns the `expiry` error, so the claim is
  untested and should be treated as unverified.
- **`/future` and `/btst` are not price feeds.** They look promising because they
  carry `expiryDate`, `strikePrice` and `optionType`, but they are trade-call
  cards: `price` is a string with a trailing comma (`"22875,"`) for futures and
  literally `"0"` for options, alongside targets and stop-losses. Do not wire
  them up as LTP.

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
