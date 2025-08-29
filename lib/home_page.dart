import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'database_helper.dart';
import 'exercise_settings_page.dart';
import 'report_page.dart';
import 'screen_util.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _exercises = [];
  int? _selectedCategory;
  int? _selectedExercise;
  final TextEditingController _repController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  int _timerSeconds = 60;
  bool _loading = true;
  bool _isTiming = false;
  int _remainingSeconds = 0;
  Timer? _timer;
  final AudioPlayer _audioPlayer = AudioPlayer();

  int _navIndex = 0;
  int reps = 12;
  double weight = 30;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadSettings();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _db.getCategories();
    final savedCat = prefs.getInt('selectedCategory');
    int? firstCat = cats.isNotEmpty ? cats.first['id'] as int : null;
    int? catId = savedCat != null && cats.any((c) => c['id'] == savedCat)
        ? savedCat
        : firstCat;

    List<Map<String, dynamic>> exs = [];
    if (catId != null) {
      exs = await _db.getExercises(catId);
    }
    final savedEx = prefs.getInt('selectedExercise');
    int? exId = savedEx != null && exs.any((e) => e['id'] == savedEx)
        ? savedEx
        : (exs.isNotEmpty ? exs.first['id'] as int : null);

    setState(() {
      _categories = cats;
      _selectedCategory = catId;
      _exercises = exs;
      _selectedExercise = exId;
      _loading = false;
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _timerSeconds = prefs.getInt('timerSeconds') ?? _timerSeconds;
      reps = prefs.getInt('reps') ?? reps;
      _weightUnit = prefs.getString('weightUnit') ?? _weightUnit;
      weight = prefs.getDouble('weight') ?? weight;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('timerSeconds', _timerSeconds);
    await prefs.setInt('reps', reps);
    await prefs.setDouble('weight', weight);
    await prefs.setString('weightUnit', _weightUnit);
    if (_selectedCategory != null) {
      await prefs.setInt('selectedCategory', _selectedCategory!);
    }
    if (_selectedExercise != null) {
      await prefs.setInt('selectedExercise', _selectedExercise!);
    }
  }

  @override
  void dispose() {
    _repController.dispose();
    _weightController.dispose();
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _onCategoryChanged(int? id) async {
    if (id == null) return;
    final exs = await _db.getExercises(id);
    setState(() {
      _selectedCategory = id;
      _exercises = exs;
      _selectedExercise = exs.isNotEmpty ? exs.first['id'] as int : null;
    });
    unawaited(_saveSettings());
  }

  Future<void> _startWorkout() async {
    final exId = _selectedExercise;
    //final reps = int.tryParse(_repController.text);
    //final weight = double.tryParse(_weightController.text);
    if (exId == null) return;
    await _db.logWorkout(exId, reps, weight, _weightUnit);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('開始計時')));
    setState(() {
      _isTiming = true;
      _remainingSeconds = _timerSeconds;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 1) {
        setState(() => _remainingSeconds--);
      } else {
        t.cancel();
        if (!mounted) return;
        unawaited(_audioPlayer.play(AssetSource('readytowork.mp3')));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('計時完成')));
        setState(() {
          _isTiming = false;
        });
      }
    });
  }

  void _toggleWeightUnit() {
    setState(() {
      if (_weightUnit == 'kg') {
        weight = weight * 2.20462;
        _weightUnit = 'lb';
      } else {
        weight = weight / 2.20462;
        _weightUnit = 'kg';
      }
    });
    unawaited(_saveSettings());
  }

  void _showTimerDialog() {
    final controller = TextEditingController(text: _timerSeconds.toString());
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('設定組間休息秒數'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _timerSeconds =
                      int.tryParse(controller.text) ?? _timerSeconds;
                });
                unawaited(_saveSettings());
                Navigator.pop(context);
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _isTiming,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: ScreenUtil.w(20)),
            child: Column(
              children: [
                SizedBox(height: ScreenUtil.h(20)),
                // 美化下拉 1：部位
                prettyDropdown<int>(
                  context: context,
                  label: '部位',
                  value: _selectedCategory,
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c['id'] as int,
                          child: Text(c['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: _onCategoryChanged,
                ),

                SizedBox(height: ScreenUtil.h(12)),
                // 美化下拉 2：動作
                prettyDropdown<int>(
                  context: context,
                  label: '動作',
                  value: _selectedExercise,
                  items: _exercises
                      .map(
                        (e) => DropdownMenuItem(
                          value: e['id'] as int,
                          child: Text(e['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    setState(() => _selectedExercise = id);
                    unawaited(_saveSettings());
                  },
                ),
                SizedBox(height: ScreenUtil.h(16)),

                // 數值列：左右留白已由外層 padding 提供
                NumberRow(
                  label: '次數',
                  valueText: reps.toString(),
                  onMinus: () {
                    setState(() => reps = (reps - 1).clamp(0, 999));
                    unawaited(_saveSettings());
                  },
                  onPlus: () {
                    setState(() => reps = (reps + 1).clamp(0, 999));
                    unawaited(_saveSettings());
                  },
                  onSubmitted: (v) {
                    setState(() => reps = int.tryParse(v) ?? reps);
                    unawaited(_saveSettings());
                  },
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                SizedBox(height: ScreenUtil.h(12)),
                NumberRow(
                  label: '重量',
                  labelTrailing: OutlinedButton(
                    onPressed: _toggleWeightUnit,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(_weightUnit),
                  ),
                  valueText: weight.toStringAsFixed(1),
                  onMinus: () {
                    setState(() => weight = (weight - 0.5).clamp(0, 999));
                    unawaited(_saveSettings());
                  },
                  onPlus: () {
                    setState(() => weight = (weight + 0.5).clamp(0, 999));
                    unawaited(_saveSettings());
                  },
                  onSubmitted: (v) {
                    setState(() => weight = double.tryParse(v) ?? weight);
                    unawaited(_saveSettings());
                  },
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,1}'),
                    ),
                  ],
                ),
                Expanded(
                  child: Center(
                    child: ElevatedButton(
                      onPressed: _isTiming ? null : _startWorkout,
                      style: ElevatedButton.styleFrom(
                        shape: const CircleBorder(),
                        minimumSize: Size.square(ScreenUtil.w(100)),
                      ),
                      child: Text(_isTiming ? '$_remainingSeconds' : '開始'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(indicatorColor: Colors.transparent),
        child: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (i) => setState(() {
            _navIndex = i;
            switch (i) {
              case 0:
                _showTimerDialog();
                break;
              case 1:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportPage()),
                );
                break;
              case 2:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExerciseSettingsPage(),
                  ),
                ).then((_) => _loadData());
                break;
            }
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.timer), label: '計時'),
            NavigationDestination(icon: Icon(Icons.bar_chart), label: '報表'),
            NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
          ],
        ),
      ),
    );
  }
}

// 下拉樣式（M3 外觀）
Widget prettyDropdown<T>({
  required BuildContext context,
  required String label,
  required T? value,
  required List<DropdownMenuItem<T>> items,
  required ValueChanged<T?> onChanged,
}) {
  final cs = Theme.of(context).colorScheme;
  return DropdownButtonFormField<T>(
    value: value,
    isExpanded: true,
    items: items,
    onChanged: onChanged,
    icon: const Icon(Icons.keyboard_arrow_down_rounded),
    decoration: InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cs.surfaceContainerHighest,
      contentPadding: EdgeInsets.symmetric(
        horizontal: ScreenUtil.w(16),
        vertical: ScreenUtil.h(14),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ScreenUtil.w(16)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ScreenUtil.w(16)),
        borderSide: BorderSide(color: Theme.of(context).dividerColor),
      ),
    ),
  );
}

/// 含 +/- 與可輸入的數值列
class NumberRow extends StatefulWidget {
  const NumberRow({
    super.key,
    required this.label,
    required this.valueText,
    required this.onMinus,
    required this.onPlus,
    required this.onSubmitted,
    this.keyboardType = TextInputType.number,
    this.inputFormatters,
    this.labelTrailing,
  });

  final String label;
  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onSubmitted;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? labelTrailing;

  @override
  State<NumberRow> createState() => _NumberRowState();
}

class _NumberRowState extends State<NumberRow> {
  late final TextEditingController _c = TextEditingController(
    text: widget.valueText,
  );

  @override
  void didUpdateWidget(covariant NumberRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valueText != widget.valueText) {
      _c.text = widget.valueText;
      _c.selection = TextSelection.fromPosition(
        TextPosition(offset: _c.text.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(ScreenUtil.w(8)),
        child: Row(
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
            if (widget.labelTrailing != null) ...[
              SizedBox(width: ScreenUtil.w(8)),
              widget.labelTrailing!,
            ],
            const Spacer(),
            OutlinedButton(
              onPressed: widget.onMinus,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              child: const Icon(Icons.remove),
            ),
            SizedBox(width: ScreenUtil.w(8)),
            SizedBox(
              width: ScreenUtil.w(56),
              child: TextField(
                controller: _c,
                textAlign: TextAlign.center,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                onSubmitted: widget.onSubmitted,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            SizedBox(width: ScreenUtil.w(8)),
            OutlinedButton(
              onPressed: widget.onPlus,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
