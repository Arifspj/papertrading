import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/market/lot_sizes.dart';
import '../../../core/theme/cyber_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/symbol_formatter.dart';
import '../../../models/position.dart';
import '../../../widgets/instrument_title.dart';

/// Trade direction chosen in the [OrderPadSheet].
enum OrderPadAction { buy, sell }

/// Kite-style Order Pad bottom sheet (reference "Order Execution" screen).
/// For an open position the default side is Sell; for a squared-off position
/// it is Buy. The side can be toggled. Returns the confirmed action or null.
Future<OrderPadAction?> showOrderPadSheet(
  BuildContext context, {
  required Position position,
}) {
  return _showOrderPad(
    context,
    position: position,
    initialSide: position.isClosed ? OrderPadAction.buy : OrderPadAction.sell,
    initialQty: position.isClosed
        ? (LotSizes.forSymbol(position.symbol) ?? 1).toDouble()
        : position.quantity.abs().toDouble(),
  );
}

/// Order Pad for a watchlist quote (no open position yet). Defaults to Buy
/// with exactly one lot of the underlying.
Future<OrderPadAction?> showWatchOrderPadSheet(
  BuildContext context, {
  required String symbol,
  required String segment,
  required double lastPrice,
  required double change,
}) {
  // One lot of the underlying. Unknown symbols fall back to 1 share so the
  // pad is still usable for cash instruments.
  final lot = LotSizes.forSymbol(symbol) ?? 1;
  return _showOrderPad(
    context,
    position: Position(
      symbol: symbol,
      quantity: lot,
      // "Previous close" implied by the quote so the change row matches.
      averagePrice: lastPrice - change,
      lastTradedPrice: lastPrice,
      pnl: 0,
      product: 'MIS',
      segment: segment,
    ),
    initialSide: OrderPadAction.buy,
    initialQty: lot.toDouble(),
  );
}

Future<OrderPadAction?> _showOrderPad(
  BuildContext context, {
  required Position position,
  required OrderPadAction initialSide,
  required double initialQty,
}) {
  return showModalBottomSheet<OrderPadAction>(
    context: context,
    backgroundColor: const Color(0xFFF4F6F8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    isScrollControlled: true,
    builder: (_) => _OrderPadSheet(
      position: position,
      initialSide: initialSide,
      initialQty: initialQty,
    ),
  );
}

const _sheetBg = Color(0xFFF4F6F8);

enum _TabKind { regular, iceberg }

enum _ProductKind { intraday, overnight }

class _OrderPadSheet extends StatefulWidget {
  final Position position;
  final OrderPadAction initialSide;
  final double initialQty;

  const _OrderPadSheet({
    required this.position,
    required this.initialSide,
    required this.initialQty,
  });

  @override
  State<_OrderPadSheet> createState() => _OrderPadSheetState();
}

class _OrderPadSheetState extends State<_OrderPadSheet> {
  late OrderPadAction _side;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _limitCtrl;
  _TabKind _tab = _TabKind.regular;
  _ProductKind _product = _ProductKind.overnight;
  bool _moreOpen = false;

  /// Lot size for the traded underlying, resolved from the symbol.
  late final int _lotSize;

  /// Ticks up whenever the qty field changes, so the footer can re-validate.
  int _qtyVersion = 0;

  @override
  void initState() {
    super.initState();
    final p = widget.position;
    _side = widget.initialSide;
    _lotSize = LotSizes.forSymbol(p.symbol) ?? 1;
    // Seed a tradable quantity: keep [initialQty] when it already lands on a
    // whole lot, otherwise fall back to the nearest lot at or below it.
    final seed = LotSizes.isValidQty(widget.initialQty, _lotSize)
        ? widget.initialQty
        : LotSizes.nearestValidQty(widget.initialQty, _lotSize, roundUp: true)
            .toDouble();
    _qtyCtrl = TextEditingController(
      text: seed > 0 ? formatQty(seed) : '$_lotSize',
    );
    _limitCtrl = TextEditingController(text: formatPlain(p.lastTradedPrice));
    _qtyCtrl.addListener(_onQtyChanged);
  }

  void _onQtyChanged() {
    final next = _qtyCtrl.text;
    // Ignore pure-formatting edits (e.g. a trailing "." from the keypad).
    if (double.tryParse(next) == null && next.isNotEmpty) return;
    setState(() => _qtyVersion++);
  }

  @override
  void dispose() {
    _qtyCtrl.removeListener(_onQtyChanged);
    _qtyCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  /// Quantity currently typed in the form, or null when unparsable.
  double? get _qty => double.tryParse(_qtyCtrl.text.trim());

  /// Reason the qty cannot be traded, or null when it is valid.
  String? get _qtyError {
    final q = _qty;
    if (q == null) return null;
    return LotSizes.validationMessage(q, _lotSize);
  }

  bool get _canSubmit => _qtyError == null && (_qty ?? 0) > 0;

  void _confirm(OrderPadAction action) {
    if (!_canSubmit) return;
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.position;
    final isBuy = _side == OrderPadAction.buy;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: TradePalette.slate200,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          _Header(position: p, onBack: () => Navigator.of(context).pop()),
          _PriceRow(position: p),
          _Tabs(
            selected: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _FormBox(
                    qtyCtrl: _qtyCtrl,
                    limitCtrl: _limitCtrl,
                    lotSize: _lotSize,
                    qtyError: _qtyError,
                    product: _product,
                    onProductChanged: (v) => setState(() => _product = v),
                  ),
                  _MoreToggle(
                    open: _moreOpen,
                    position: p,
                    lotSize: _lotSize,
                    onToggle: () => setState(() => _moreOpen = !_moreOpen),
                  ),
                ],
              ),
            ),
          ),
          _StickyFooter(
            position: p,
            isBuy: isBuy,
            side: _side,
            liveQty: _qty,
            qtyError: _qtyError,
            canSubmit: _canSubmit,
            onSideChanged: (s) => setState(() => _side = s),
            onComplete: _confirm,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Position position;
  final VoidCallback onBack;

  const _Header({required this.position, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              LucideIcons.chevronLeft,
              size: 24,
              color: TradePalette.slate600,
            ),
          ),
          Flexible(
            child: InstrumentTitle(
              symbol: position.symbol,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              LucideIcons.ellipsisVertical,
              size: 20,
              color: TradePalette.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final Position position;

  const _PriceRow({required this.position});

  @override
  Widget build(BuildContext context) {
    final p = position;
    final changeAmt = p.lastTradedPrice - p.averagePrice;
    final pct = p.averagePrice == 0
        ? 0.0
        : (changeAmt / p.averagePrice) * 100;
    final up = changeAmt >= 0;
    final color = up ? TradePalette.positiveGreen : TradePalette.negativeRed;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Text(
            p.segment,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: TradePalette.slate500,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '\u20B9 ${formatPlain(p.lastTradedPrice)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${up ? '+' : ''}${formatPlain(changeAmt)} '
            '(${up ? '+' : ''}${formatPlain(pct)}%)',
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

class _Tabs extends StatelessWidget {
  final _TabKind selected;
  final ValueChanged<_TabKind> onChanged;

  const _Tabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _tabButton(_TabKind.regular, 'Regular'),
          const SizedBox(width: 24),
          _tabButton(_TabKind.iceberg, 'Iceberg'),
        ],
      ),
    );
  }

  Widget _tabButton(_TabKind kind, String label) {
    final active = selected == kind;
    return GestureDetector(
      onTap: () => onChanged(kind),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? TradePalette.primary : TradePalette.slate400,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: active ? 24 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: TradePalette.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormBox extends StatelessWidget {
  final TextEditingController qtyCtrl;
  final TextEditingController limitCtrl;
  final _ProductKind product;
  final ValueChanged<_ProductKind> onProductChanged;
  final int lotSize;

  /// Non-null when the typed quantity is not a valid multiple of [lotSize].
  final String? qtyError;

  const _FormBox({
    required this.qtyCtrl,
    required this.limitCtrl,
    required this.product,
    required this.onProductChanged,
    required this.lotSize,
    required this.qtyError,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TradePalette.slate200),
      ),
      child: Column(
        children: [
          _InputRow(
            label: 'Quantity',
            hint: '',
            controller: qtyCtrl,
            errorText: qtyError,
            onSubmitted: (text) => _snapToLot(text),
          ),
          _LotHint(
            lotSize: lotSize,
            error: qtyError,
            onPick: (lots) => _applyLots(lots),
          ),
          const SizedBox(height: 14),
          _InputRow(
            label: 'Limit',
            hint: '',
            controller: limitCtrl,
            withEdit: true,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _radio('Intraday', product == _ProductKind.intraday, () {
                onProductChanged(_ProductKind.intraday);
              }),
              const SizedBox(width: 32),
              _radio(
                  'Overnight', product == _ProductKind.overnight, () {
                onProductChanged(_ProductKind.overnight);
              }),
            ],
          ),
        ],
      ),
    );
  }

  void _applyLots(int lots) {
    final next = (lots * lotSize).toString();
    qtyCtrl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  /// Round the typed quantity down onto a whole number of lots.
  void _snapToLot(String text) {
    final q = double.tryParse(text.trim());
    if (q == null) return;
    final snapped = LotSizes.nearestValidQty(q, lotSize);
    if (snapped == 0 || snapped == q) return;
    _applyLots((snapped / lotSize).round());
  }

  Widget _radio(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? TradePalette.primary : TradePalette.slate300,
                width: selected ? 5 : 1.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? TradePalette.slate900 : TradePalette.slate600,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Lot size 65 · 1x 2x 3x 5x" quick-multiplier strip under the qty field.
class _LotHint extends StatelessWidget {
  final int lotSize;
  final String? error;
  final ValueChanged<int> onPick;

  const _LotHint({required this.lotSize, required this.error, required this.onPick});

  static const _multipliers = [1, 2, 3, 5];

  @override
  Widget build(BuildContext context) {
    final invalid = error != null;
    final color = invalid ? TradePalette.negativeRed : TradePalette.slate500;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Text(
            'Lot $lotSize',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          for (final m in _multipliers) ...[
            _chip(m, invalid),
            const SizedBox(width: 6),
          ],
          const Spacer(),
          Flexible(
            child: Text(
              invalid ? 'Qty must be a multiple' : 'Qty in lots',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: invalid
                    ? TradePalette.negativeRed
                    : TradePalette.slate400,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(int multiplier, bool invalid) {
    return GestureDetector(
      onTap: () => onPick(multiplier),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: invalid ? TradePalette.red50 : TradePalette.slate100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: invalid ? TradePalette.negativeRed : TradePalette.slate200,
          ),
        ),
        child: Text(
          '${multiplier}x',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: invalid ? TradePalette.negativeRed : TradePalette.slate600,
          ),
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool withEdit;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  const _InputRow({
    required this.label,
    required this.hint,
    required this.controller,
    this.withEdit = false,
    this.errorText,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: TradePalette.slate700,
              ),
            ),
            if (withEdit) ...[
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.pencil,
                size: 13,
                color: TradePalette.primary,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: TextField(
            controller: controller,
            onSubmitted: onSubmitted,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: TradePalette.slate900,
            ),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              errorText: errorText,
              errorStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: TradePalette.negativeRed,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: errorText != null
                      ? TradePalette.negativeRed
                      : TradePalette.slate300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: errorText != null
                      ? TradePalette.negativeRed
                      : TradePalette.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MoreToggle extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final Position position;
  final int lotSize;

  const _MoreToggle({
    required this.open,
    required this.onToggle,
    required this.position,
    required this.lotSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                const Text(
                  'More',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: TradePalette.slate500,
                  ),
                ),
                Icon(
                  open ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  size: 16,
                  color: TradePalette.slate400,
                ),
              ],
            ),
          ),
        ),
        if (open)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: TradePalette.slate200),
            ),
            child: Column(
              children: [
                _MoreRow(
                  'Instrument type',
                  SymbolParts.parse(position.symbol).instrumentLabel,
                ),
                const SizedBox(height: 12),
                _MoreRow('Product', position.product),
                const SizedBox(height: 12),
                _MoreRow('Lot size', '$lotSize units'),
                const SizedBox(height: 12),
                _MoreRow('Lot size as of', 'Nov 2026'),
              ],
            ),
          ),
      ],
    );
  }
}

class _MoreRow extends StatelessWidget {
  final String label;
  final String value;

  const _MoreRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: TradePalette.slate500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TradePalette.slate700,
          ),
        ),
      ],
    );
  }
}

class _StickyFooter extends StatelessWidget {
  final Position position;
  final bool isBuy;
  final OrderPadAction side;
  final ValueChanged<OrderPadAction> onSideChanged;
  final ValueChanged<OrderPadAction> onComplete;

  /// Quantity currently in the qty field, used for the live margin estimate.
  /// Null when the field is empty or unparsable.
  final double? liveQty;

  final String? qtyError;
  final bool canSubmit;

  const _StickyFooter({
    required this.position,
    required this.isBuy,
    required this.side,
    required this.onSideChanged,
    required this.onComplete,
    required this.liveQty,
    required this.qtyError,
    required this.canSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _sheetBg,
        border: Border(
          top: BorderSide(color: TradePalette.slate200),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        children: [
          _marginRow(),
          const SizedBox(height: 8),
          _sideSwitcher(),
          const SizedBox(height: 8),
          if (qtyError != null) ...[
            _blockedBanner(qtyError!),
            const SizedBox(height: 8),
          ],
          _SwipeButton(
            color: canSubmit
                ? (isBuy ? TradePalette.primary : TradePalette.negativeRed)
                : TradePalette.slate300,
            label: canSubmit
                ? (isBuy ? 'Swipe to Buy' : 'Swipe to Sell')
                : 'Qty must be a multiple of the lot',
            onComplete: () => onComplete(side),
          ),
        ],
      ),
    );
  }

  Widget _blockedBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: TradePalette.red50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TradePalette.negativeRed),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.circleAlert,
            size: 14,
            color: TradePalette.negativeRed,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: TradePalette.negativeRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _marginRow() {
    final qty = liveQty ?? position.quantity.abs();
    final margin = qty * position.lastTradedPrice;
    return Row(
      children: [
        const Text(
          'Margin',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: TradePalette.slate500,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '\u20B9${formatPlain(margin)}',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: TradePalette.primary,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          '|',
          style: TextStyle(fontSize: 11, color: TradePalette.slate300),
        ),
        const SizedBox(width: 8),
        const Text(
          'Avail.',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: TradePalette.slate500,
          ),
        ),
        const SizedBox(width: 6),
        const Text(
          '\u20B922.30',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: TradePalette.primary,
          ),
        ),
        const Spacer(),
        const Icon(
          LucideIcons.refreshCw,
          size: 14,
          color: TradePalette.slate400,
        ),
      ],
    );
  }

  Widget _sideSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TradePalette.slate200,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          _seg(
            l: 'Sell',
            active: !isBuy,
            color: TradePalette.negativeRed,
            onTap: () => onSideChanged(OrderPadAction.sell),
          ),
          _seg(
            l: 'Buy',
            active: isBuy,
            color: TradePalette.positiveGreen,
            onTap: () => onSideChanged(OrderPadAction.buy),
          ),
        ],
      ),
    );
  }

  Widget _seg({
    required String l,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: active
                ? const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            l,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? color : TradePalette.slate500,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeButton extends StatefulWidget {
  final Color color;
  final String label;
  final VoidCallback onComplete;

  const _SwipeButton({
    required this.color,
    required this.label,
    required this.onComplete,
  });

  @override
  State<_SwipeButton> createState() => _SwipeButtonState();
}

class _SwipeButtonState extends State<_SwipeButton> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const knob = 44.0;
        const inset = 4.0;
        final maxDrag = constraints.maxWidth - knob - inset * 2;
        return GestureDetector(
          onHorizontalDragUpdate: (det) {
            setState(() {
              _dx = (_dx + det.delta.dx).clamp(0.0, maxDrag);
            });
          },
          onHorizontalDragEnd: (_) {
            if (_dx >= maxDrag * 0.75) {
              widget.onComplete();
            } else {
              setState(() => _dx = 0);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: inset + _dx,
                  top: inset,
                  child: Container(
                    width: knob,
                    height: knob,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 22,
                      color: widget.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}