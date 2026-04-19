import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  Casio fx-991ES Plus — Full Recreation
//  Modes: COMP · STAT · TABLE · EQN · MATRIX · VECTOR · BASE-N · CMPLX
// ═════════════════════════════════════════════════════════════════════════════
class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});
  @override State<CalculatorScreen> createState() => _CalcState();
}

enum CalcMode { comp, stat, table, eqn, matrix, baseN, cmplx }

class _CalcState extends State<CalculatorScreen>
    with SingleTickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────────────────────
  // ignore: unused_field
  CalcMode _mode     = CalcMode.comp;
  bool _isDeg        = true;
  bool _isShift      = false;
  bool _isAlpha      = false;
  bool _justEval     = false;

  String _expr       = '';
  String _display    = '0';
  String _result     = '';
  String _memory     = '0';
  String _ans        = '0';

  // STAT mode data
  final List<double> _statX = [];
  final List<double> _statY = [];

  // TABLE mode
  String _tableExpr  = '';
  double _tableStart = 0, _tableEnd = 10, _tableStep = 1;

  // EQN mode
  final List<TextEditingController> _eqnCtrl = List.generate(6, (_) => TextEditingController());
  int _eqnDegree = 2;  // 2 = quadratic, 3 = cubic; or simultaneous

  // MATRIX
  final List<List<TextEditingController>> _matA =
      List.generate(3, (_) => List.generate(3, (_) => TextEditingController(text: '0')));
  final List<List<TextEditingController>> _matB =
      List.generate(3, (_) => List.generate(3, (_) => TextEditingController(text: '0')));
  int _matRows = 2, _matCols = 2;

  late TabController _modeTab;

  @override
  void initState() {
    super.initState();
    _modeTab = TabController(length: CalcMode.values.length, vsync: this);
    _modeTab.addListener(() {
      if (!_modeTab.indexIsChanging) return;
      setState(() {
        _mode = CalcMode.values[_modeTab.index];
        _isShift = false; _isAlpha = false;
      });
    });
  }

  @override
  void dispose() {
    _modeTab.dispose();
    for (final c in _eqnCtrl) {
      c.dispose();
    }
    for (final row in _matA) for (final c in row) {
      c.dispose();
    }
    for (final row in _matB) for (final c in row) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Button press ───────────────────────────────────────────────────────────
  void _press(String k) {
    HapticFeedback.lightImpact();
    setState(() {
      if (k == 'AC') { _expr=''; _display='0'; _result=''; _justEval=false; return; }
      if (k == 'DEL') {
        if (_expr.isNotEmpty) _expr = _expr.substring(0, _expr.length-1);
        _display = _expr.isEmpty ? '0' : _expr;
        _result = '';  _justEval = false;
        return;
      }
      if (k == 'SHIFT') { _isShift = !_isShift; _isAlpha = false; return; }
      if (k == 'ALPHA') { _isAlpha = !_isAlpha; _isShift = false; return; }
      if (k == 'DEG/RAD') { _isDeg = !_isDeg; return; }

      if (k == 'M+') { _memory = _fmtN((_parseN(_memory))+(double.tryParse(_result.replaceAll('= ','')) ?? 0)); return; }
      if (k == 'M-') { _memory = _fmtN((_parseN(_memory))-(double.tryParse(_result.replaceAll('= ','')) ?? 0)); return; }
      if (k == 'MR') { _expr += _memory; _display=_expr; return; }
      if (k == 'MC') { _memory = '0'; return; }

      if (k == '=') { _evaluate(); return; }
      if (k == 'ANS') { if (_justEval) { _expr=_ans; } else { _expr+=_ans; } _display=_expr; _justEval=false; return; }

      if (_justEval && _isDigit(k)) { _expr=''; _justEval=false; }
      else if (_justEval && _isOp(k)) { _expr=_ans; _justEval=false; }
      else { _justEval=false; }

      _expr += _tok(k);
      _display = _expr;
      _isShift = false; _isAlpha = false;

      // Live preview
      try {
        final r = _Parser(_expr, _isDeg).parse();
        if (!r.isNaN) _result = _fmtN(r);
      } catch (_) { _result = ''; }
    });
  }

  bool _isDigit(String k) => '0123456789.π e'.contains(k);
  bool _isOp(String k)    => '+-×÷^'.contains(k);

  String _tok(String k) {
    if (_isShift) {
      if (k=='sin') return 'asin(';
      if (k=='cos') return 'acos(';
      if (k=='tan') return 'atan(';
      if (k=='log') return '10^(';
      if (k=='ln')  return 'e^(';
      if (k=='x²')  return '^(1/2)';   // √ when shift+x²
      if (k=='x³')  return '^(1/3)';
      if (k=='ENG') return 'e^(';
    }
    switch (k) {
      case '×':   return '*';
      case '÷':   return '/';
      case 'x²':  return '^2';
      case 'x³':  return '^3';
      case 'xʸ':  return '^';
      case '√':   return 'sqrt(';
      case '∛':   return 'cbrt(';
      case 'sin': return 'sin(';
      case 'cos': return 'cos(';
      case 'tan': return 'tan(';
      case 'log': return 'log(';
      case 'ln':  return 'ln(';
      case '1/x': return '1/(';
      case 'n!':  return 'fact(';
      case '%':   return '/100';
      case 'π':   return 'π';
      case 'e':   return 'e';
      case 'EXP': return '×10^(';
      case 'Abs': return 'abs(';
      case '±':   return '(-';
      case '(':   return '(';
      case ')':   return ')';
      case ',':   return ',';
      case 'nPr': return 'nPr(';
      case 'nCr': return 'nCr(';
      case 'Pol': return 'Pol(';
      case 'Rec': return 'Rec(';
      case 'Rnd': return 'Rnd(';
      default:    return k;
    }
  }

  void _evaluate() {
    if (_expr.isEmpty) return;
    try {
      // Replace π and e with values
      String e = _expr.replaceAll('π', '3.14159265358979')
                      .replaceAll('e', '2.71828182845905');
      final r = _Parser(e, _isDeg).parse();
      _ans     = _fmtN(r);
      _result  = '= $_ans';
      _justEval = true;
    } catch (err) {
      _result = 'Math ERROR';
    }
  }

  double _parseN(String s) => double.tryParse(s) ?? 0;

  String _fmtN(double v) {
    if (v.isNaN || v.isInfinite) return v.isNaN ? 'Math ERROR' : (v>0 ? '∞' : '-∞');
    if (v == v.truncateToDouble() && v.abs() < 1e12) return v.toInt().toString();
    if (v.abs() >= 1e10 || (v.abs() < 1e-4 && v != 0)) {
      return v.toStringAsExponential(6)
          .replaceAll(RegExp(r'\.?0+(e)'), r'\1');
    }
    String s = v.toStringAsFixed(10);
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return s;
  }

  // ── STAT calculations ──────────────────────────────────────────────────────
  Map<String,String> _calcStats() {
    if (_statX.isEmpty) return {'Error': 'No data'};
    final n   = _statX.length.toDouble();
    final sx  = _statX.fold(0.0,(a,b)=>a+b);
    final sx2 = _statX.fold(0.0,(a,b)=>a+b*b);
    final mean = sx/n;
    final variance = sx2/n - mean*mean;
    final sd  = sqrt(variance);
    final ssd = sqrt((sx2 - sx*sx/n)/(n-1));
    Map<String,String> r = {
      'n':    _fmtN(n),
      'Σx':   _fmtN(sx),
      'Σx²':  _fmtN(sx2),
      'x̄':   _fmtN(mean),
      'σx':   _fmtN(sd),
      'sx':   _fmtN(ssd),
      'Min':  _fmtN(_statX.reduce(min)),
      'Max':  _fmtN(_statX.reduce(max)),
    };
    if (_statY.length == _statX.length && _statY.isNotEmpty) {
      final sy  = _statY.fold(0.0,(a,b)=>a+b);
      final sxy = List.generate(_statX.length,(i)=>_statX[i]*_statY[i]).fold(0.0,(a,b)=>a+b);
      final sy2 = _statY.fold(0.0,(a,b)=>a+b*b);
      final meanY = sy/n;
      final b = (sxy - sx*sy/n)/(sx2 - sx*sx/n);
      final a = meanY - b*mean;
      final r2 = pow((sxy-sx*sy/n)/sqrt((sx2-sx*sx/n)*(sy2-sy*sy/n)),2);
      r['ȳ']  = _fmtN(meanY);
      r['A']  = _fmtN(a);
      r['B']  = _fmtN(b);
      r['r²'] = _fmtN(r2.toDouble());
      r['r']  = _fmtN(sqrt(r2.toDouble()));
    }
    return r;
  }

  // ── EQN solver ─────────────────────────────────────────────────────────────
  List<String> _solveEqn() {
    try {
      final v = _eqnCtrl.map((c) => double.tryParse(c.text) ?? 0).toList();
      if (_eqnDegree == 2) {
        // ax²+bx+c=0
        final a=v[0], b=v[1], c=v[2];
        if (a==0) return ['Not quadratic'];
        final disc = b*b - 4*a*c;
        if (disc < 0) {
          final re = -b/(2*a);
          final im = sqrt(-disc)/(2*a);
          return ['x1 = ${ _fmtN(re)} + ${_fmtN(im)}i',
                  'x2 = ${_fmtN(re)} - ${_fmtN(im)}i'];
        }
        return ['x1 = ${_fmtN((-b+sqrt(disc))/(2*a))}',
                'x2 = ${_fmtN((-b-sqrt(disc))/(2*a))}'];
      } else if (_eqnDegree == 3) {
        // Cardano for ax³+bx²+cx+d=0
        final a=v[0], b=v[1], c=v[2], d=v[3];
        if (a==0) return ['Not cubic'];
        final p = (3*a*c - b*b)/(3*a*a);
        final q = (2*b*b*b - 9*a*b*c + 27*a*a*d)/(27*a*a*a);
        final disc = q*q/4 + p*p*p/27;
        final shift = -b/(3*a);
        if (disc > 0) {
          final u = _cbrt(-q/2 + sqrt(disc));
          final w = _cbrt(-q/2 - sqrt(disc));
          return ['x1 = ${_fmtN(shift + u + w)}',
                  'x2 = Complex', 'x3 = Complex'];
        } else if (disc == 0) {
          final u = _cbrt(-q/2);
          return ['x1 = ${_fmtN(shift+2*u)}',
                  'x2 = ${_fmtN(shift-u)}',
                  'x3 = ${_fmtN(shift-u)}'];
        } else {
          final m = 2*sqrt(-p/3);
          final t = acos(3*q/(p*m))/3;
          return ['x1 = ${_fmtN(shift+m*cos(t))}',
                  'x2 = ${_fmtN(shift+m*cos(t-2*pi/3))}',
                  'x3 = ${_fmtN(shift+m*cos(t-4*pi/3))}'];
        }
      } else {
        // Simultaneous 2×2: ax+by=e, cx+dy=f
        final a=v[0],b=v[1],e=v[2],c=v[3],d=v[4],f=v[5];
        final det=a*d-b*c;
        if (det==0) return ['No unique solution'];
        return ['x = ${_fmtN((e*d-b*f)/det)}',
                'y = ${_fmtN((a*f-e*c)/det)}'];
      }
    } catch(_) { return ['Error']; }
  }

  double _cbrt(double x) => x<0 ? -pow(-x,1/3).toDouble() : pow(x,1/3).toDouble();

  // ── MATRIX operations ──────────────────────────────────────────────────────
  List<List<double>> _readMat(List<List<TextEditingController>> ctrl) =>
    ctrl.sublist(0,_matRows).map((row) =>
      row.sublist(0,_matCols).map((c) => double.tryParse(c.text)??0).toList()
    ).toList();

  String _matDet(List<List<double>> m) {
    if (m.length==2) return _fmtN(m[0][0]*m[1][1]-m[0][1]*m[1][0]);
    if (m.length==3) {
      return _fmtN(
        m[0][0]*(m[1][1]*m[2][2]-m[1][2]*m[2][1])
       -m[0][1]*(m[1][0]*m[2][2]-m[1][2]*m[2][0])
       +m[0][2]*(m[1][0]*m[2][1]-m[1][1]*m[2][0])
      );
    }
    return 'N/A';
  }

  List<List<double>> _matMul(List<List<double>> a, List<List<double>> b) {
    final n = a.length, m = b[0].length, k = b.length;
    return List.generate(n,(i)=>List.generate(m,(j)=>
      List.generate(k,(l)=>a[i][l]*b[l][j]).fold(0.0,(s,v)=>s+v)));
  }

  String _matToStr(List<List<double>> m) =>
    m.map((row)=>'[${row.map(_fmtN).join(', ')}]').join('\n');

  // ── TABLE generation ───────────────────────────────────────────────────────
  List<Map<String,String>> _genTable() {
    final rows = <Map<String,String>>[];
    if (_tableExpr.isEmpty) return rows;
    double x = _tableStart;
    while (x <= _tableEnd + 1e-9) {
      try {
        final expr = _tableExpr.replaceAll('x', '($x)')
            .replaceAll('π','3.14159265358979')
            .replaceAll('e','2.71828182845905');
        final y = _Parser(expr, _isDeg).parse();
        rows.add({'x': _fmtN(x), 'f(x)': _fmtN(y)});
      } catch (_) {
        rows.add({'x': _fmtN(x), 'f(x)': 'ERROR'});
      }
      x += _tableStep;
      if (rows.length > 200) break;
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark ? const Color(0xFF080D1A) : const Color(0xFF0D1B2A);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
        title: Row(children: [
          const Text('fx-991ES Plus',
              style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.w900, fontSize: 18)),
          const Spacer(),
          _chip(_isDeg ? 'DEG' : 'RAD', Colors.amber,
              onTap: () => setState(() => _isDeg = !_isDeg)),
          const SizedBox(width: 6),
          if (_isShift) _chip('SHIFT', Colors.orange),
          if (_isAlpha) _chip('ALPHA', Colors.red),
          if (_memory != '0') _chip('M', Colors.green),
        ]),
        bottom: TabBar(
          controller: _modeTab,
          isScrollable: true,
          indicatorColor: const Color(0xFF4CC9F0),
          labelColor: const Color(0xFF4CC9F0),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'COMP'),
            Tab(text: 'STAT'),
            Tab(text: 'TABLE'),
            Tab(text: 'EQN'),
            Tab(text: 'MATRIX'),
            Tab(text: 'BASE-N'),
            Tab(text: 'CMPLX'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _modeTab,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildComp(bg),
          _buildStat(),
          _buildTable(),
          _buildEqn(),
          _buildMatrix(),
          _buildBaseN(bg),
          _buildCmplx(bg),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, {VoidCallback? onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Text(label, style: TextStyle(color: color,
            fontSize: 10, fontWeight: FontWeight.w800)),
      ),
    );

  // ══════════════════════════════════════════════════════════════════════════
  //  COMP mode
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildComp(Color bg) => Column(children: [
    // Display
    Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10,8,10,6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Memory
        if (_memory != '0')
          Text('M: $_memory',
              style: const TextStyle(color: Colors.green, fontSize: 11)),
        // Expression
        SingleChildScrollView(
          scrollDirection: Axis.horizontal, reverse: true,
          child: Text(_display,
              style: const TextStyle(color: Color(0xFFAAFFAA),
                  fontSize: 15, fontFamily: 'monospace')),
        ),
        const SizedBox(height: 4),
        // Result
        Text(
          _result,
          style: TextStyle(
            color: _result.contains('ERROR') ? Colors.red
                : const Color(0xFF00FF88),
            fontSize: _justEval ? 28 : 18,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
          ),
        ),
      ]),
    ),
    // Keyboard
    Expanded(child: _buildKeyboard()),
  ]);

  Widget _buildKeyboard() {
    return LayoutBuilder(builder: (ctx, box) {
      final rows = _keyRows();
      final rowH = box.maxHeight / rows.length;
      return Column(
        children: rows.map((row) => SizedBox(
          height: rowH,
          child: Row(children: row.map((btn) => Expanded(
            flex: btn.flex,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: _buildBtn(btn, rowH - 4),
            ),
          )).toList()),
        )).toList(),
      );
    });
  }

  List<List<_K>> _keyRows() => [
    // Row 1
    [_K('SHIFT','ctrl'), _K('ALPHA','ctrl'), _K(_isShift?'3√':'√','fn'),
     _K(_isShift?'x⁻¹':'x²','fn'), _K(_isShift?'eˣ':'ln','fn')],
    // Row 2
    [_K(_isShift?'sin⁻¹':'sin','fn'), _K(_isShift?'cos⁻¹':'cos','fn'),
     _K(_isShift?'tan⁻¹':'tan','fn'), _K(_isShift?'10^x':'log','fn'),
     _K('Abs','fn')],
    // Row 3
    [_K('nPr','fn'), _K('nCr','fn'), _K('Pol','fn'), _K('Rec','fn'), _K('Rnd','fn')],
    // Row 4
    [_K('ENG','fn'), _K('(','op'), _K(')','op'), _K('M+','mem'), _K('M-','mem')],
    // Row 5
    [_K('MR','mem'), _K('MC','mem'), _K('DEL','ctrl'), _K('AC','ctrl'), _K('%','op')],
    // Row 6
    [_K('7','num'), _K('8','num'), _K('9','num'), _K('÷','op'), _K('π','fn')],
    // Row 7
    [_K('4','num'), _K('5','num'), _K('6','num'), _K('×','op'), _K('e','fn')],
    // Row 8
    [_K('1','num'), _K('2','num'), _K('3','num'), _K('-','op'), _K('xʸ','fn')],
    // Row 9
    [_K('0','num',flex:2), _K('.','num'), _K('ANS','fn'),
     _K('+','op'), _K('=','eq')],
  ];

  Widget _buildBtn(_K btn, double h) {
    const bgMap = {
      'fn':   Color(0xFF0D2135),
      'op':   Color(0xFF0A1E30),
      'eq':   Color(0xFF006633),
      'num':  Color(0xFF111827),
      'mem':  Color(0xFF1A0D35),
      'ctrl': Color(0xFF200A10),
    };
    const fgMap = {
      'fn':   Color(0xFFFF9F1C),
      'op':   Color(0xFF4CC9F0),
      'eq':   Color(0xFF00FF88),
      'num':  Colors.white,
      'mem':  Color(0xFFBB86FC),
      'ctrl': Color(0xFFFF6B6B),
    };
    final bgC = bgMap[btn.type] ?? const Color(0xFF111827);
    final fgC = fgMap[btn.type] ?? Colors.white;

    String pressKey = btn.label;
    // Map display labels back to internal keys
    if (pressKey == 'sin⁻¹') pressKey = 'sin';
    if (pressKey == 'cos⁻¹') pressKey = 'cos';
    if (pressKey == 'tan⁻¹') pressKey = 'tan';
    if (pressKey == '10^x')  pressKey = 'log';
    if (pressKey == 'eˣ')    pressKey = 'ln';
    if (pressKey == 'x⁻¹')   pressKey = 'x²'; // shift+x² = √x handled in _tok
    if (pressKey == '3√')     pressKey = '∛';

    return GestureDetector(
      onTap: () => _press(pressKey),
      child: Container(
        decoration: BoxDecoration(
          color: bgC,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: fgC.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: fgC.withOpacity(0.12),
              blurRadius: 4, offset: const Offset(0,2))],
        ),
        child: Center(child: Text(btn.label,
          style: TextStyle(color: fgC,
              fontSize: btn.label.length > 4 ? 9 : 13,
              fontWeight: FontWeight.w700),
        )),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STAT mode
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStat() {
    final stats = _calcStats();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        // Data entry
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            const Text('STAT DATA', style: TextStyle(color: Colors.amber,
                fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _statField('x', _statX)),
              const SizedBox(width: 8),
              Expanded(child: _statField('y (opt)', _statY)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
                onPressed: () => setState(() { _statX.clear(); _statY.clear(); }),
                icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.white),
                label: const Text('Clear', style: TextStyle(color: Colors.white, fontSize: 12)),
              )),
            ]),
          ]),
        ),
        // Results
        Expanded(child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: stats.entries.map((e) => _statRow(e.key, e.value)).toList(),
        )),
      ]),
    );
  }

  Widget _statField(String label, List<double> list) {
    final ctrl = TextEditingController();
    return Row(children: [
      Expanded(child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
          filled: true, fillColor: const Color(0xFF1C2333),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
      )),
      const SizedBox(width: 4),
      IconButton(
        icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF06D6A0), size: 22),
        onPressed: () {
          final v = double.tryParse(ctrl.text);
          if (v != null) { setState(() => list.add(v)); ctrl.clear(); }
        },
        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
      ),
    ]);
  }

  Widget _statRow(String k, String v) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF111827),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(children: [
      Text(k, style: const TextStyle(color: Colors.amber,
          fontWeight: FontWeight.w700, fontSize: 14)),
      const Spacer(),
      Text(v, style: const TextStyle(color: Colors.white,
          fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'monospace')),
    ]),
  );

  // ══════════════════════════════════════════════════════════════════════════
  //  TABLE mode
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildTable() {
    final rows = _genTable();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFF111827),
              borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            const Text('f(x) TABLE', style: TextStyle(color: Colors.amber,
                fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _tableExpr = v),
              style: const TextStyle(color: Colors.white),
              decoration: _inputDeco('f(x) = e.g. x^2+2x+1'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _numField('Start', _tableStart, (v) => _tableStart = v)),
              const SizedBox(width: 6),
              Expanded(child: _numField('End', _tableEnd, (v) => _tableEnd = v)),
              const SizedBox(width: 6),
              Expanded(child: _numField('Step', _tableStep, (v) => _tableStep = v)),
            ]),
          ]),
        ),
        if (rows.isEmpty)
          const Expanded(child: Center(child: Text('Enter f(x) above',
              style: TextStyle(color: Colors.white54))))
        else
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Table(
              border: TableBorder.all(color: Colors.white12),
              children: [
                TableRow(children: [
                  _tCell('x', header: true),
                  _tCell('f(x)', header: true),
                ]),
                ...rows.map((r) => TableRow(children: [
                  _tCell(r['x']!),
                  _tCell(r['f(x)']!, colored: true),
                ])),
              ],
            ),
          )),
      ]),
    );
  }

  Widget _tCell(String t, {bool header=false, bool colored=false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
    child: Text(t, textAlign: TextAlign.center,
        style: TextStyle(
          color: header ? Colors.amber : (colored ? const Color(0xFF4CC9F0) : Colors.white70),
          fontWeight: header ? FontWeight.w800 : FontWeight.w400,
          fontSize: 12, fontFamily: 'monospace',
        )),
  );

  Widget _numField(String label, double val, Function(double) onSet) {
    final c = TextEditingController(text: val.toString());
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      onChanged: (v) { final d=double.tryParse(v); if(d!=null) setState(()=>onSet(d)); },
      style: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: _inputDeco(label),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EQN mode
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEqn() {
    final sols = _solveEqn();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('EQUATION SOLVER', style: TextStyle(color: Colors.amber,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          // Mode selector
          SegmentedButton<int>(
            selected: {_eqnDegree},
            onSelectionChanged: (s) => setState(() => _eqnDegree = s.first),
            segments: const [
              ButtonSegment(value: 2, label: Text('Quadratic', style: TextStyle(fontSize: 11))),
              ButtonSegment(value: 3, label: Text('Cubic', style: TextStyle(fontSize: 11))),
              ButtonSegment(value: 4, label: Text('2×2 Simult.', style: TextStyle(fontSize: 11))),
            ],
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                  s.contains(WidgetState.selected) ? const Color(0xFF1A3A4A) : const Color(0xFF111827)),
            ),
          ),
          const SizedBox(height: 14),
          // Coefficient fields
          if (_eqnDegree == 2) ...[
            _eqLabel('ax² + bx + c = 0'),
            _eqRow(['a', 'b', 'c'], [0, 1, 2]),
          ] else if (_eqnDegree == 3) ...[
            _eqLabel('ax³ + bx² + cx + d = 0'),
            _eqRow(['a', 'b', 'c', 'd'], [0, 1, 2, 3]),
          ] else ...[
            _eqLabel('ax + by = e'),
            _eqRow(['a', 'b', 'e'], [0, 1, 2]),
            const SizedBox(height: 6),
            _eqLabel('cx + dy = f'),
            _eqRow(['c', 'd', 'f'], [3, 4, 5]),
          ],
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),
          const Text('SOLUTIONS', style: TextStyle(color: Colors.amber,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...sols.map((s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1E30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF4CC9F0).withOpacity(0.3)),
            ),
            child: Text(s, style: const TextStyle(
                color: Color(0xFF4CC9F0), fontSize: 15,
                fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          )),
        ]),
      ),
    );
  }

  Widget _eqLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: const TextStyle(color: Colors.white54, fontSize: 12)),
  );

  Widget _eqRow(List<String> labels, List<int> indices) => Row(
    children: List.generate(labels.length, (i) => Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: TextField(
          controller: _eqnCtrl[indices[i]],
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: _inputDeco(labels[i]),
        ),
      ),
    )),
  );

  // ══════════════════════════════════════════════════════════════════════════
  //  MATRIX mode
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildMatrix() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          const Text('MATRIX CALCULATOR', style: TextStyle(color: Colors.amber,
              fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          // Size selector
          Row(children: [
            const Text('Size:', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: _matRows,
              dropdownColor: const Color(0xFF111827),
              style: const TextStyle(color: Colors.white),
              items: [2,3].map((n) => DropdownMenuItem(value: n,
                  child: Text('$n×$n'))).toList(),
              onChanged: (v) => setState(() => _matRows = _matCols = v!),
            ),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _matGrid('A', _matA)),
            const SizedBox(width: 8),
            Expanded(child: _matGrid('B', _matB)),
          ]),
          const SizedBox(height: 12),
          // Operations
          Wrap(spacing: 8, runSpacing: 8, children: [
            _matOpBtn('det(A)', () {
              final m = _readMat(_matA);
              _showResult('det(A) = ${_matDet(m)}');
            }),
            _matOpBtn('A + B', () {
              final a=_readMat(_matA), b=_readMat(_matB);
              final r=List.generate(_matRows,(i)=>
                  List.generate(_matCols,(j)=>a[i][j]+b[i][j]));
              _showResult('A+B =\n${_matToStr(r)}');
            }),
            _matOpBtn('A × B', () {
              final a=_readMat(_matA), b=_readMat(_matB);
              _showResult('A×B =\n${_matToStr(_matMul(a, b))}');
            }),
            _matOpBtn('Aᵀ', () {
              final a=_readMat(_matA);
              final t=List.generate(_matCols,(j)=>
                  List.generate(_matRows,(i)=>a[i][j]));
              _showResult('Aᵀ =\n${_matToStr(t)}');
            }),
          ]),
        ]),
      ),
    );
  }

  Widget _matGrid(String name, List<List<TextEditingController>> ctrl) =>
    Column(children: [
      Text(name, style: const TextStyle(color: Colors.amber,
          fontWeight: FontWeight.w800, fontSize: 14)),
      const SizedBox(height: 6),
      ...List.generate(_matRows, (i) => Row(
        children: List.generate(_matCols, (j) => Expanded(
          child: Container(
            margin: const EdgeInsets.all(2),
            child: TextField(
              controller: ctrl[i][j],
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              style: const TextStyle(color: Colors.white, fontSize: 11),
              decoration: _inputDeco(''),
            ),
          ),
        )),
      )),
    ]);

  Widget _matOpBtn(String label, VoidCallback onTap) => ElevatedButton(
    style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0D2135),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
    onPressed: onTap,
    child: Text(label, style: const TextStyle(
        color: Color(0xFF4CC9F0), fontSize: 12, fontWeight: FontWeight.w700)),
  );

  void _showResult(String r) => showDialog(context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF111827),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Result', style: TextStyle(color: Colors.amber)),
      content: SelectableText(r,
          style: const TextStyle(color: Colors.white,
              fontFamily: 'monospace', fontSize: 15)),
      actions: [TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('OK', style: TextStyle(color: Color(0xFF4CC9F0))))],
    ));

  // ══════════════════════════════════════════════════════════════════════════
  //  BASE-N mode
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBaseN(Color bg) {
    return _BaseNWidget(bg: bg);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CMPLX mode
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildCmplx(Color bg) {
    return _CmplxWidget(bg: bg, isDeg: _isDeg);
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white30, fontSize: 11),
    filled: true, fillColor: const Color(0xFF1C2333),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );
}

class _K { final String label, type; final int flex;
  const _K(this.label, this.type, {this.flex = 1}); }

// ─────────────────────────────────────────────────────────────────────────────
//  BASE-N Widget
// ─────────────────────────────────────────────────────────────────────────────
class _BaseNWidget extends StatefulWidget {
  final Color bg;
  const _BaseNWidget({required this.bg});
  @override State<_BaseNWidget> createState() => _BaseNWidgetState();
}
class _BaseNWidgetState extends State<_BaseNWidget> {
  int _base = 10;
  String _input = '';
  int? _value;

  void _pressKey(String k) {
    setState(() {
      if (k == 'AC')  { _input = ''; _value = null; return; }
      if (k == 'DEL') { if (_input.isNotEmpty) _input = _input.substring(0,_input.length-1); }
      else             { _input += k; }
      try {
        _value = int.parse(_input, radix: _base);
      } catch (_) { _value = null; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final v = _value;
    final rows10 = [
      ['7','8','9'], ['4','5','6'], ['1','2','3'],
      ['0','AC','DEL']
    ];
    final hexExtra = ['A','B','C','D','E','F'];

    return Column(children: [
      // Base selector
      Container(
        margin: const EdgeInsets.fromLTRB(12,8,12,4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _baseBtn('BIN',2), _baseBtn('OCT',8),
            _baseBtn('DEC',10), _baseBtn('HEX',16),
          ],
        ),
      ),
      // Display
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF0A2A1A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_input.isEmpty ? '0' : _input,
              style: const TextStyle(color: Color(0xFFAAFFAA),
                  fontSize: 20, fontFamily: 'monospace',
                  fontWeight: FontWeight.w700)),
          if (v != null) ...[
            const Divider(color: Colors.green, height: 10),
            _convRow('BIN', v.toRadixString(2)),
            _convRow('OCT', v.toRadixString(8)),
            _convRow('DEC', v.toString()),
            _convRow('HEX', v.toRadixString(16).toUpperCase()),
          ],
        ]),
      ),
      // HEX extra keys
      if (_base == 16)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: hexExtra.map((k) => Expanded(child: Padding(
            padding: const EdgeInsets.all(2),
            child: _hexBtn(k),
          ))).toList()),
        ),
      // Number pad
      Expanded(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(children: rows10.map((row) => Expanded(
          child: Row(children: row.map((k) => Expanded(child: Padding(
            padding: const EdgeInsets.all(2),
            child: GestureDetector(
              onTap: () => _pressKey(k),
              child: Container(
                decoration: BoxDecoration(
                  color: k == 'AC' ? const Color(0xFF200A10)
                      : k == 'DEL' ? const Color(0xFF1A0A10)
                      : const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Center(child: Text(k,
                    style: TextStyle(
                      color: k=='AC' ? const Color(0xFFFF6B6B)
                          : k=='DEL' ? Colors.orange : Colors.white,
                      fontWeight: FontWeight.w700, fontSize: 15))),
              ),
            ),
          ))).toList()),
        )).toList()),
      )),
    ]);
  }

  Widget _baseBtn(String label, int base) => GestureDetector(
    onTap: () => setState(() { _base = base; _input = ''; _value = null; }),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _base == base ? const Color(0xFF1A3A4A) : const Color(0xFF111827),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: _base == base ? const Color(0xFF4CC9F0) : Colors.white12),
      ),
      child: Text(label, style: TextStyle(
          color: _base == base ? const Color(0xFF4CC9F0) : Colors.white54,
          fontWeight: FontWeight.w800, fontSize: 13)),
    ),
  );

  Widget _hexBtn(String k) => GestureDetector(
    onTap: () => _pressKey(k),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          color: const Color(0xFF1A0D35),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFBB86FC).withOpacity(0.3))),
      child: Center(child: Text(k,
          style: const TextStyle(color: Color(0xFFBB86FC),
              fontWeight: FontWeight.w700, fontSize: 14))),
    ),
  );

  Widget _convRow(String base, String val) => Row(children: [
    Text('$base:', style: const TextStyle(color: Colors.white38,
        fontSize: 11, fontFamily: 'monospace')),
    const SizedBox(width: 8),
    Expanded(child: Text(val, textAlign: TextAlign.right,
        style: const TextStyle(color: Color(0xFFAAFFAA),
            fontSize: 12, fontFamily: 'monospace'))),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
//  CMPLX Widget — complex number operations
// ─────────────────────────────────────────────────────────────────────────────
class _CmplxWidget extends StatefulWidget {
  final Color bg; final bool isDeg;
  const _CmplxWidget({required this.bg, required this.isDeg});
  @override State<_CmplxWidget> createState() => _CmplxWidgetState();
}
class _CmplxWidgetState extends State<_CmplxWidget> {
  final _a1 = TextEditingController(text: '3');
  final _b1 = TextEditingController(text: '4');
  final _a2 = TextEditingController(text: '1');
  final _b2 = TextEditingController(text: '2');

  double get a1 => double.tryParse(_a1.text)??0;
  double get b1 => double.tryParse(_b1.text)??0;
  double get a2 => double.tryParse(_a2.text)??0;
  double get b2 => double.tryParse(_b2.text)??0;

  String _fmt(double r, double i) {
    final rs = r == r.truncateToDouble() ? r.toInt().toString() : r.toStringAsFixed(4);
    final is_ = i == i.truncateToDouble() ? i.toInt().abs().toString() : i.abs().toStringAsFixed(4);
    if (i == 0) return rs;
    if (r == 0) return '${i >= 0 ? '' : '-'}${is_}i';
    return '$rs ${i >= 0 ? '+' : '-'} ${is_}i';
  }

  @override
  Widget build(BuildContext context) {
    final mag1 = sqrt(a1*a1+b1*b1);
    final ang1 = atan2(b1,a1)*(widget.isDeg?180/pi:1);
    // ignore: unused_local_variable
    final mag2 = sqrt(a2*a2+b2*b2);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('COMPLEX NUMBERS', style: TextStyle(color: Colors.amber,
            fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _cRow('z₁ =', _a1, _b1),
        const SizedBox(height: 8),
        _cRow('z₂ =', _a2, _b2),
        const SizedBox(height: 12),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),
        _res('z₁ + z₂', _fmt(a1+a2, b1+b2)),
        _res('z₁ − z₂', _fmt(a1-a2, b1-b2)),
        _res('z₁ × z₂', _fmt(a1*a2-b1*b2, a1*b2+b1*a2)),
        _res('z₁ ÷ z₂', () {
          final d = a2*a2+b2*b2;
          if (d==0) return 'Undefined';
          return _fmt((a1*a2+b1*b2)/d, (b1*a2-a1*b2)/d);
        }()),
        _res('|z₁|', mag1.toStringAsFixed(6)),
        _res('arg(z₁)', '${ang1.toStringAsFixed(4)}${widget.isDeg ? '°' : ' rad'}'),
        _res('z₁* (conj)', _fmt(a1, -b1)),
        _res('z₁² ', _fmt(a1*a1-b1*b1, 2*a1*b1)),
        _res('√z₁', () {
          final r = sqrt(mag1);
          final t = atan2(b1,a1)/2;
          return _fmt(r*cos(t), r*sin(t));
        }()),
      ]),
    );
  }

  Widget _cRow(String label, TextEditingController ca, TextEditingController cb) =>
    Row(children: [
      SizedBox(width: 36, child: Text(label,
          style: const TextStyle(color: Colors.amber, fontSize: 13,
              fontWeight: FontWeight.w700))),
      const SizedBox(width: 6),
      Expanded(child: _cField(ca, 'a (real)')),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 6),
          child: const Text('+', style: TextStyle(color: Colors.white54, fontSize: 18))),
      Expanded(child: _cField(cb, 'b (imag)')),
      const Padding(padding: EdgeInsets.only(left: 4),
          child: Text('i', style: TextStyle(color: Color(0xFF4CC9F0),
              fontSize: 18, fontWeight: FontWeight.w800))),
    ]);

  Widget _cField(TextEditingController c, String hint) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
    onChanged: (_) => setState(() {}),
    style: const TextStyle(color: Colors.white, fontSize: 13),
    textAlign: TextAlign.center,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 10),
      filled: true, fillColor: const Color(0xFF1C2333),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
  );

  Widget _res(String label, String val) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(color: const Color(0xFF0A1E30),
        borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      const Spacer(),
      Text(val, style: const TextStyle(color: Color(0xFF4CC9F0),
          fontSize: 13, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Math expression parser
// ─────────────────────────────────────────────────────────────────────────────
class _Parser {
  final String src; final bool isDeg;
  int _pos = 0;
  _Parser(this.src, this.isDeg);

  double parse() { final v=_expr(); return v; }

  double _expr() {
    double v = _term();
    while (_pos < src.length) {
      if      (_cur=='+') { _pos++; v += _term(); }
      else if (_cur=='-') { _pos++; v -= _term(); }
      else break;
    }
    return v;
  }

  double _term() {
    double v = _power();
    while (_pos < src.length) {
      if      (_cur=='*') { _pos++; v *= _power(); }
      else if (_cur=='/') { _pos++; final d=_power(); v = d==0 ? double.nan : v/d; }
      else break;
    }
    return v;
  }

  double _power() {
    double v = _unary();
    if (_pos < src.length && _cur=='^') { _pos++; v=pow(v,_power()).toDouble(); }
    return v;
  }

  double _unary() {
    if (_pos<src.length && _cur=='-') { _pos++; return -_atom(); }
    if (_pos<src.length && _cur=='+') { _pos++; return _atom(); }
    return _atom();
  }

  double _atom() {
    _ws();
    if (_pos>=src.length) throw FormatException('EOF');

    if (_cur=='('){ _pos++; final v=_expr(); if(_pos<src.length&&_cur==')') _pos++; return v; }

    if (_isNum(_cur)) return _number();

    final fn = _ident(); _ws();
    double arg=0;
    if (_pos<src.length && _cur=='(') {
      _pos++; arg=_expr(); if(_pos<src.length&&_cur==')') _pos++;
    } else { arg=_atom(); }

    double r(double Function(double) f, [bool angleIn=false, bool angleOut=false]) {
      final a = (angleIn && isDeg) ? arg*pi/180 : arg;
      final v = f(a);
      return (angleOut && isDeg) ? v*180/pi : v;
    }

    switch (fn) {
      case 'sin':   return r(sin, true);
      case 'cos':   return r(cos, true);
      case 'tan':   return r(tan, true);
      case 'asin':  return r(asin, false, true);
      case 'acos':  return r(acos, false, true);
      case 'atan':  return r(atan, false, true);
      case 'log':   return log(arg)/ln10;
      case 'ln':    return log(arg);
      case 'sqrt':  return sqrt(arg);
      case 'cbrt':  return arg<0 ? -pow(-arg,1/3).toDouble() : pow(arg,1/3).toDouble();
      case 'abs':   return arg.abs();
      case 'fact':  return _fact(arg.round()).toDouble();
      case 'nPr':   { final n=arg.round(); final rr=(_lastCommaArg??0).round(); return (_fact(n)/_fact(n-rr)).toDouble(); }
      case 'nCr':   { final n=arg.round(); final rr=(_lastCommaArg??0).round(); return (_fact(n)/(_fact(rr)*_fact(n-rr))).toDouble(); }
      case 'Rnd':   return double.parse(arg.toStringAsFixed(9));
      default:      throw FormatException('Unknown: $fn');
    }
  }

  double? _lastCommaArg;

  double _number() {
    final s=_pos;
    while (_pos<src.length && (_isNum(_cur)||_cur=='.'||
        (_cur=='e'||_cur=='E')&&(_pos+1<src.length))) {
      _pos++;
    }
    return double.parse(src.substring(s,_pos));
  }

  String _ident() {
    final s=_pos;
    while (_pos<src.length && RegExp(r'[a-zA-Z_]').hasMatch(_cur)) {
      _pos++;
    }
    return src.substring(s,_pos);
  }

  void _ws() { while (_pos<src.length && _cur==' ') {
    _pos++;
  } }
  bool _isNum(String c) => c.codeUnitAt(0)>=48&&c.codeUnitAt(0)<=57;
  String get _cur => src[_pos];

  int _fact(int n) {
    if (n<0||n>20) throw ArgumentError('factorial');
    int r=1; for (int i=2;i<=n;i++) {
      r*=i;
    } return r;
  }
}