# Lot Sizes (F&O)

Exchange lot sizes are **revised every month**. This table is pinned to the
**November 2026** circular and is validated by tests, so a stale table fails
loudly instead of silently sending an invalid order.

## Where it lives

- Table: `lib/core/market/lot_sizes.dart` (`LotSizes`)
- Enforced in: `lib/screens/positions/widgets/order_pad_sheet.dart`
- Search universe: `lib/repositories/watchlist_repository.dart`
- Tests: `test/lot_sizes_test.dart`, `test/order_pad_lot_test.dart`,
  `test/fno_catalog_test.dart`

## The rule

Quantity must be a whole number of lots:

```
lot size L
valid  -> k * L   for k >= 1
invalid-> anything else (0, negative, or a partial lot)
```

With a lot of `20`: `20`, `40`, `60` are valid; `10` and `110` are not.
With a lot of `65` (NIFTY): `65` and `130` are valid; `20` and `110` are not.

In the Order Pad this means:

- The quantity field shows a red border and an error when it is not a multiple.
- The swipe-to-buy/sell button is disabled and labelled with the reason.
- A banner above the button repeats the reason, so it is readable while the
  sheet is scrolled.
- `1x / 2x / 3x / 5x` chips fill the field with whole lots.
- Submitting the field snaps the value **down** onto the nearest whole lot, so
  a fix never increases size.
- Seed quantities are already lot-aligned: a fresh watchlist order starts at
  exactly one lot, and an open position keeps its own quantity when valid.

## Index derivatives

| Symbol | Lot |
| --- | --- |
| BANKNIFTY | 30 |
| FINNIFTY | 60 |
| MIDCPNIFTY | 120 |
| NIFTY | 65 |
| SENSEX | 20 |

## Stock F&O universe

All ~190 stock underlyings from the circular are in `LotSizes.stockLots`, with
index and stock aliases (`L&T` -> `LT`, `BANKEX` -> `BANKNIFTY`,
`NIFTYNXT50` -> `MIDCPNIFTY`, and so on). A few examples:

| Symbol | Lot | Symbol | Lot | Symbol | Lot |
| --- | --- | --- | --- | --- | --- |
| RELIANCE | 500 | TCS | 225 | INFY | 400 |
| HDFCBANK | 650 | ICICIBANK | 700 | SBIN | 750 |
| ASIANPAINT | 250 | TITAN | 175 | PAGEIND | 20 |
| ZYDUSLIFE | 900 | HINDUNILVR | 300 | BAJFINANCE | 750 |
| SUZLON | 12700 | IDEA | 71475 | YESBANK | 31100 |

Symbols **not** in the circular (e.g. `TATAMOTORS`) have no lot size and fall
back to 1 share, which is the correct cash-market behaviour.

## Unknown symbols

Two cases are deliberately **not** guessed:

1. **Cash instruments** outside the table fall back to lot `1`, so the Order Pad
   still works for equities.
2. **`LotSizes.noLotSymbols`** lists circular entries that carry no lot size
   (currently `BAJAJHLDNG`). `forSymbol` returns `null` for these, so
   `forSymbolOrDefault` yields `1` and the UI can tell the user the lot size is
   unknown instead of inventing a number.

## Keeping it fresh

Lot sizes change every monthly circular. When a new circular lands:

1. Update `LotSizes.stockLots` / `LotSizes.indexLots`.
2. Bump `LotSizes.asOf` to the new month — `asOfLabel` drives the
   "Lot size as of" row in the Order Pad.
3. Update the `Nov 2026` expectations in `test/lot_sizes_test.dart`.
4. Run `flutter test`.

The live `analysis.lot_size` field returned by HNICALLS can be used as a
runtime cross-check, but the static table stays the source of truth so order
validation never depends on a network call.
