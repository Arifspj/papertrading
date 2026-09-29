import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../core/theme/cyber_colors.dart';
import '../core/utils/formatters.dart';
import '../models/market/live_quote.dart';
import '../services/live/live_market_controller.dart';

/// Infinite marquee of market quotes, pinned under the app header.
///
/// Reads the quotes [LiveMarketController] already holds, so it costs no extra
/// network traffic: the polling stream pulls
/// `https://hnicalls.com/api/public/api/ticker_app` every cycle and this widget
/// just re-renders whatever is in the map.
///
/// The scroll is seamless because the item list is rendered twice. Offset
/// `0` and offset `maxScrollExtent` are visually identical, so wrapping the
/// jump back to zero is invisible.
class UnifiedTicker extends StatefulWidget {
  /// Scroll speed in logical pixels per second.
  final double speed;

  /// Extra quotes to append, e.g. a static header badge.
  final List<TickerChip> leading;

  const UnifiedTicker({super.key, this.speed = 42, this.leading = const []});

  @override
  State<UnifiedTicker> createState() => _UnifiedTickerState();
}

class _UnifiedTickerState extends State<UnifiedTicker>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  Ticker? _ticker;
  Duration _lastTick = Duration.zero;

  @override
  void dispose() {
    _ticker?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// The marquee only runs while the strip actually overflows. Without this
  /// gate the ticker would schedule frames forever, burning battery when there
  /// are no quotes yet and leaving the app permanently non-idle.
  void _syncAnimation() {
    if (!_scroll.hasClients) return;
    final overflows = _scroll.position.maxScrollExtent > 0;
    if (overflows) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  void _startTicker() {
    _ticker ??= createTicker(_onTick);
    if (_ticker!.isActive) return;
    _lastTick = Duration.zero;
    _ticker!.start();
  }

  void _stopTicker() {
    if (_ticker?.isActive ?? false) _ticker!.stop();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (!_scroll.hasClients || dt <= 0) return;
    final max = _scroll.position.maxScrollExtent;
    if (max <= 0) {
      _stopTicker();
      return;
    }
    var next = _scroll.offset + widget.speed * dt;
    if (next >= max) next -= max;
    if (next < 0) next = 0;
    _scroll.jumpTo(next);
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveMarketController>();
    final quotes = _tickerQuotes(live.quotes.values);
    final chips = [...widget.leading, ...quotes];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncAnimation();
    });

    return Container(
      height: 30,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: TradePalette.slate200),
        ),
      ),
      child: quotes.isEmpty
          ? Row(
              children: [
                const SizedBox(width: 16),
                _statusDot(live.isLive),
                const SizedBox(width: 8),
                Text(
                  live.isLive ? 'Connecting to market feed…' : 'Market feed idle',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: TradePalette.slate500,
                  ),
                ),
              ],
            )
          : ListView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Two identical halves make the wrap-around seamless.
                for (var pass = 0; pass < 2; pass++)
                  for (final chip in chips) _chip(chip),
              ],
            ),
    );
  }

  Widget _statusDot(bool isLive) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isLive ? TradePalette.positiveGreen : TradePalette.slate400,
      ),
    );
  }

  Widget _chip(TickerChip q) {
    final up = q.changePct >= 0;
    final color = up ? TradePalette.positiveGreen : TradePalette.negativeRed;
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Row(
        children: [
          Text(
            q.symbol,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: TradePalette.slate900,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            formatPlain(q.ltp),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: TradePalette.slate600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${up ? '+' : ''}${q.changePct.toStringAsFixed(2)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// One entry in the marquee.
class TickerChip {
  const TickerChip(this.symbol, this.ltp, this.changePct);

  final String symbol;
  final double ltp;
  final double changePct;
}

/// Index/mover quotes first, then the rest alphabetically. Cash instruments
/// with no price yet are dropped so the strip never shows a stale zero.
List<TickerChip> _tickerQuotes(Iterable<LiveQuote> quotes) {
  final seen = <String>{};
  final out = <TickerChip>[];
  for (final q in quotes) {
    if (q.ltp == 0 || !seen.add(q.symbol)) continue;
    out.add(TickerChip(q.symbol, q.ltp, q.changePct));
  }
  out.sort((a, b) => a.symbol.compareTo(b.symbol));
  return out;
}
