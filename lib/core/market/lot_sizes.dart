import '../utils/symbol_formatter.dart';

/// Contract lot sizes for the F&O segment.
/// Exchange lot sizes are **revised every month**, so [asOf] is part of the
/// table and must be bumped when the new circular lands.
///
/// Source: NSE/BSE F&O lot-size circular, November 2026 cycle.
class LotSizes {
  const LotSizes._();

  /// Month the table was last verified against the exchange circular.
  static final DateTime asOf = DateTime(2026, 11);

  /// Label shown in the Order Pad, e.g. `Nov 2026`.
  static String get asOfLabel {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[asOf.month - 1]} ${asOf.year}';
  }

  /// Index derivatives. NIFTY and SENSEX also trade weekly; the rest are
  /// monthly only.
  static const Map<String, int> indexLots = {
    'NIFTY': 65,
    'BANKNIFTY': 30,
    'FINNIFTY': 60,
    'SENSEX': 20,
    'MIDCPNIFTY': 120,
  };

  /// F&O stock universe, November 2026 lot sizes.
  static const Map<String, int> stockLots = {
    '360ONE': 500,
    'ABB': 125,
    'ABCAPITAL': 3100,
    'ADANIENSOL': 675,
    'ADANIENT': 309,
    'ADANIGREEN': 600,
    'ADANIPORTS': 475,
    'ADANIPOWER': 3550,
    'ALKEM': 125,
    'AMBER': 100,
    'AMBUJACEM': 1200,
    'ANGELONE': 2500,
    'APLAPOLLO': 350,
    'APOLLOHOSP': 125,
    'ASHOKLEY': 5000,
    'ASIANPAINT': 250,
    'ASTRAL': 425,
    'ATHERENERG': 375,
    'AUBANK': 1000,
    'AUROPHARMA': 550,
    'AXISBANK': 625,
    'BAJAJ-AUTO': 75,
    'BAJAJFINSV': 300,
    'BAJFINANCE': 750,
    'BANDHANBNK': 3600,
    'BANKBARODA': 2925,
    'BANKINDIA': 5200,
    'BDL': 425,
    'BEL': 1425,
    'BHARATFORG': 500,
    'BHARTIARTL': 475,
    'BHEL': 2625,
    'BIOCON': 2500,
    'BLUESTARCO': 325,
    'BOSCHLTD': 25,
    'BPCL': 1975,
    'BRITANNIA': 125,
    'BSE': 200,
    'CAMS': 825,
    'CANBK': 6750,
    'CDSL': 475,
    'CGPOWER': 850,
    'CHOLAFIN': 625,
    'CIPLA': 425,
    'COALINDIA': 1350,
    'COCHINSHIP': 400,
    'COFORGE': 475,
    'COLPAL': 275,
    'CONCOR': 1250,
    'CROMPTON': 2150,
    'CUMMINSIND': 200,
    'DABUR': 1250,
    'DELHIVERY': 2075,
    'DIVISLAB': 100,
    'DIXON': 50,
    'DLF': 950,
    'DMART': 150,
    'DRREDDY': 625,
    'EICHERMOT': 100,
    'ETERNAL': 2425,
    'FEDERALBNK': 2500,
    'FORCEMOT': 25,
    'FORTIS': 775,
    'GAIL': 3550,
    'GLENMARK': 375,
    'GMRAIRPORT': 6975,
    'GODFRYPHLP': 275,
    'GODREJCP': 500,
    'GODREJPROP': 325,
    'GRASIM': 250,
    'GVT&D': 125,
    'HAL': 150,
    'HAVELLS': 500,
    'HCLTECH': 400,
    'HDFCAMC': 300,
    'HDFCBANK': 650,
    'HDFCLIFE': 1100,
    'HEROMOTOCO': 150,
    'HINDALCO': 700,
    'HINDPETRO': 2025,
    'HINDUNILVR': 300,
    'HINDZINC': 1225,
    'HYUNDAI': 275,
    'ICICIBANK': 700,
    'ICICIGI': 325,
    'ICICIPRULI': 925,
    'IDEA': 71475,
    'IDFCFIRSTB': 9275,
    'IEX': 4350,
    'INDHOTEL': 1000,
    'INDIANB': 1000,
    'INDIGO': 150,
    'INDUSINDBK': 700,
    'INDUSTOWER': 1700,
    'INFY': 400,
    'INOXWIND': 6400,
    'IOC': 4875,
    'IREDA': 4525,
    'IRFC': 5425,
    'ITC': 1725,
    'JINDALSTEL': 625,
    'JIOFIN': 2350,
    'JSWENERGY': 1075,
    'JSWSTEEL': 675,
    'JUBLFOOD': 1250,
    'KALYANKJIL': 1350,
    'KAYNES': 150,
    'KEI': 175,
    'KFINTECH': 575,
    'KOTAKBANK': 2000,
    'KPITTECH': 775,
    'LAURUSLABS': 850,
    'LICHSGFIN': 1000,
    'LICI': 1400,
    'LODHA': 625,
    'LT': 175,
    'LTF': 2250,
    'LTM': 150,
    'LUPIN': 425,
    'M&M': 200,
    'MAHABANK': 6500,
    'MANAPPURAM': 3000,
    'MANKIND': 250,
    'MARICO': 1200,
    'MARUTI': 50,
    'MAXHEALTH': 525,
    'MAZDOCK': 225,
    'MCX': 225,
    'MFSL': 400,
    'MOTHERSON': 6150,
    'MOTILALOFS': 775,
    'MPHASIS': 275,
    'MUTHOOTFIN': 275,
    'NAM-INDIA': 625,
    'NATIONALUM': 1875,
    'NAUKRI': 550,
    'NBCC': 6500,
    'NESTLEIND': 500,
    'NHPC': 6950,
    'NMDC': 6750,
    'NTPC': 1500,
    'NYKAA': 3125,
    'OBEROIRLTY': 350,
    'OFSS': 100,
    'OIL': 1400,
    'ONGC': 2250,
    'PAGEIND': 20,
    'PATANJALI': 1075,
    'PAYTM': 725,
    'PERSISTENT': 125,
    'PETRONET': 1900,
    'PFC': 1300,
    'PGEL': 950,
    'PHOENIXLTD': 350,
    'PIDILITIND': 500,
    'PIIND': 175,
    'PNB': 8000,
    'PNBHOUSING': 650,
    'POLICYBZR': 350,
    'POLYCAB': 125,
    'POWERGRID': 1900,
    'POWERINDIA': 25,
    'PREMIERENE': 650,
    'PRESTIGE': 450,
    'RADICO': 150,
    'RBLBANK': 3175,
    'RECLTD': 1575,
    'RELIANCE': 500,
    'RVNL': 1925,
    'SAGILITY': 12000,
    'SAIL': 4700,
    'SBICARD': 800,
    'SBILIFE': 375,
    'SBIN': 750,
    'SHREECEM': 25,
    'SHRIRAMFIN': 825,
    'SIEMENS': 175,
    'SOLARINDS': 50,
    'SONACOMS': 1225,
    'SRF': 200,
    'SUNPHARMA': 350,
    'SUPREMEIND': 175,
    'SUZLON': 12700,
    'SWIGGY': 1825,
    'TATACONSUM': 550,
    'TATAELXSI': 125,
    'TATAPOWER': 1450,
    'TATASTEEL': 2750,
    'TCS': 225,
    'TECHM': 600,
    'TIINDIA': 200,
    'TITAN': 175,
    'TMPV': 1600,
    'TORNTPHARM': 125,
    'TRENT': 225,
    'TVSMOTOR': 175,
    'ULTRACEMCO': 50,
    'UNIONBANK': 4425,
    'UNITDSPR': 400,
    'UNOMINDA': 550,
    'UPL': 1355,
    'VBL': 1275,
    'VEDL': 1150,
    'VMM': 4850,
    'VOLTAS': 375,
    'WAAREEENER': 175,
    'WIPRO': 3000,
    'YESBANK': 31100,
    'ZYDUSLIFE': 900,
  };

  /// Symbols in the supplied circular that carry no lot size, e.g. BAJAJHLDNG.
  /// They are not in the F&O derivatives segment for this cycle.
  static const Set<String> noLotSymbols = {'BAJAJHLDNG'};

  /// Broker/exchange spellings that differ from the NSE circular symbol.
  static const Map<String, String> aliases = {
    'L&T': 'LT',
    'M&M': 'M&M',
    'BAJAJ AUTO': 'BAJAJ-AUTO',
    'NAM INDIA': 'NAM-INDIA',
    'GVT D': 'GVT&D',
    'NIFTYBANK': 'BANKNIFTY',
    'BANKEX': 'BANKNIFTY',
    'NIFTYIT': 'FINNIFTY',
    'NIFTYNXT50': 'MIDCPNIFTY',
    'NIFTY50': 'NIFTY',
  };

  /// Every symbol with a known lot size, indices first.
  static Map<String, int> get all => {...indexLots, ...stockLots};

  static List<String> get symbols => all.keys.toList(growable: false);

  /// Lot size for a bare instrument/underlying, e.g. `NIFTY` or `RELIANCE`.
  static int? forInstrument(String instrument) {
    final raw = instrument.trim().toUpperCase();
    if (raw.isEmpty) return null;
    // Resolve exact/alias keys before stripping digits, otherwise index
    // aliases that end in a number (NIFTYNXT50) are destroyed.
    final direct = _lookup(raw);
    if (direct != null) return direct;
    return _lookup(_stripContract(raw));
  }

  static int? _lookup(String key) => all[key] ?? all[aliases[key]];

  /// Lot size resolved from a full app symbol such as
  /// `NIFTY 24 OCT 22700 CE` or `SENSEX 01st OCT 72900 PE`.
  static int? forSymbol(String symbol) =>
      forInstrument(SymbolParts.parse(symbol).apiInstrument);

  /// Lot size, falling back to a sane default so the UI can still validate.
  static int forSymbolOrDefault(String symbol, {int fallback = 1}) =>
      forSymbol(symbol) ?? fallback;

  /// Alias keys that resolve to [symbol], e.g. `L&T` for `LT`. Lets search
  /// find `LT` when the user types the broker spelling.
  static List<String> aliasKeysFor(String symbol) {
    final key = symbol.trim().toUpperCase();
    return aliases.entries
        .where((e) => e.value == key)
        .map((e) => e.key)
        .toList(growable: false);
  }

  /// Every underlying an F&O order can be placed on, sorted for the search
  /// sheet. Index derivatives are spaced first so NIFTY/SENSEX stay on top.
  static List<String> get fnoUnderlyings {
    final indices = indexLots.keys.toList()..sort();
    final stocks = stockLots.keys.toList()..sort();
    return [...indices, ...stocks];
  }

  /// True when [qty] is a whole number of lots.
  static bool isValidQty(num qty, int lotSize) {
    if (lotSize <= 0) return false;
    if (qty <= 0) return false;
    return (qty % lotSize).abs() < 1e-9;
  }

  /// How many lots [qty] represents, or null when the qty is not a multiple.
  static int? lotsFor(num qty, int lotSize) {
    if (!isValidQty(qty, lotSize)) return null;
    return (qty / lotSize).round();
  }

  /// Nearest tradable quantity to [qty]. Used to suggest a fix in the UI.
  /// Rounds **down** by default so the suggestion never increases risk.
  static int nearestValidQty(num qty, int lotSize, {bool roundUp = false}) {
    if (lotSize <= 0) return 0;
    if (qty <= 0) return 0;
    final lots = qty / lotSize;
    final rounded = roundUp ? lots.ceil() : lots.floor();
    return rounded * lotSize;
  }

  /// A short, human message explaining why a qty is rejected.
  static String? validationMessage(num qty, int lotSize) {
    if (lotSize <= 0) return 'Lot size unavailable for this symbol';
    if (qty <= 0) return 'Quantity must be greater than 0';
    if (isValidQty(qty, lotSize)) return null;
    final nearest = nearestValidQty(qty, lotSize);
    final suffix = nearest == 0 ? '${lotSize}x' : '$nearest';
    return 'Lot size $lotSize — use a multiple of $lotSize (nearest $suffix)';
  }

  /// Reduce a broker contract string to its bare underlying:
  /// `NIFTY25NOV22700CE` -> `NIFTY`, `01st OCT 72900 PE` -> `OCT`.
  static String _stripContract(String raw) {
    var s = raw;
    s = s.replaceAll(
      RegExp(r'(CE|PE|FUT|CALL|PUT|FUTIDX|OPTIDX)\s*$'),
      '',
    );
    // "01st OCT" / "24TH NOV" ordinal month markers.
    s = s.replaceAll(RegExp(r'\d{1,2}(ST|ND|RD|TH)\b'), '');
    // Expiry block: 25NOV22700, 27AUG2026, 20260827.
    s = s.replaceAll(RegExp(r'\d{1,4}[A-Z]{3}\d*'), '');
    s = s.replaceAll(RegExp(r'\d{8}'), '');
    s = s.replaceAll(RegExp(r'\d'), '');
    s = s.replaceAll(RegExp(r'[^A-Z&.\-]'), '');
    return s.trim();
  }
}
