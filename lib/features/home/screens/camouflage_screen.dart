import 'package:flutter/material.dart';

class CamouflageScreen extends StatefulWidget {
  const CamouflageScreen({super.key});
  @override
  State<CamouflageScreen> createState() => _CamouflageScreenState();
}

class _CamouflageScreenState extends State<CamouflageScreen> {
  String _display = '0';
  double? _operand;
  String? _operator;
  bool _shouldReset = false;
  void _press(String key) => setState(() {
    if (key == 'AC') {
      _display = '0';
      _operand = null;
      _operator = null;
      _shouldReset = false;
      return;
    }
    if (key == '±') {
      if (_display != '0') {
        _display = _display.startsWith('-')
            ? _display.substring(1)
            : '-$_display';
      }
      return;
    }
    if (key == '%') {
      _display = _format((double.tryParse(_display) ?? 0) / 100);
      return;
    }
    if (['+', '−', '×', '÷', '='].contains(key)) {
      final current = double.tryParse(_display) ?? 0;
      if (_operand != null && _operator != null && !_shouldReset) {
        final result = switch (_operator) {
          '+' => _operand! + current,
          '−' => _operand! - current,
          '×' => _operand! * current,
          '÷' => current == 0 ? double.nan : _operand! / current,
          _ => current,
        };
        _display = result.isFinite ? _format(result) : 'Lỗi';
      }
      _operand = double.tryParse(_display);
      _operator = key == '=' ? null : key;
      _shouldReset = true;
      return;
    }
    if (_shouldReset || _display == 'Lỗi') {
      _display = '0';
      _shouldReset = false;
    }
    if (key == '.' && _display.contains('.')) {
      return;
    }
    if (_display.length >= 12) {
      return;
    }
    _display = _display == '0' && key != '.' ? key : '$_display$key';
  });
  String _format(double number) => number == number.roundToDouble()
      ? number.toInt().toString()
      : double.parse(number.toStringAsPrecision(9)).toString();
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Quay lại',
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white54,
                    ),
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    child: Text(
                      _display,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                for (final row in [
                  ['AC', '±', '%', '÷'],
                  ['7', '8', '9', '×'],
                  ['4', '5', '6', '−'],
                  ['1', '2', '3', '+'],
                  ['0', '.', '='],
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        for (final key in row)
                          Expanded(
                            flex: key == '0' ? 2 : 1,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: SizedBox(
                                height: 66,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    backgroundColor:
                                        ['÷', '×', '−', '+', '='].contains(key)
                                        ? const Color(0xFFFF9F0A)
                                        : const Color(0xFF303033),
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: () => _press(key),
                                  child: Text(
                                    key,
                                    style: const TextStyle(fontSize: 27),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
