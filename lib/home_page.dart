import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'database_helper.dart';
import 'exercise_settings_page.dart';
import 'report_page.dart';

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

  int _navIndex = 0;
  int reps = 12;
  double weight = 30;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final cats = await _db.getCategories();
    int? firstCat = cats.isNotEmpty ? cats.first['id'] as int : null;
    List<Map<String, dynamic>> exs = [];
    if (firstCat != null) {
      exs = await _db.getExercises(firstCat);
    }
    setState(() {
      _categories = cats;
      _selectedCategory = firstCat;
      _exercises = exs;
      _selectedExercise = exs.isNotEmpty ? exs.first['id'] as int : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _repController.dispose();
    _weightController.dispose();
    _timer?.cancel();
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
  }

  Future<void> _startWorkout() async {
    final exId = _selectedExercise;
    final reps = int.tryParse(_repController.text);
    final weight = double.tryParse(_weightController.text);
    if (exId == null || reps == null || weight == null) return;
    await _db.logWorkout(exId, reps, weight);
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
        SystemSound.play(SystemSoundType.alert);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('計時完成')));
        setState(() {
          _isTiming = false;
        });
      }
    });
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: AbsorbPointer(
        absorbing: _isTiming,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<int>(
                value: _selectedCategory,
                items: _categories
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: c['id'] as int,
                        child: Text(c['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: _onCategoryChanged,
              ),
              DropdownButton<int>(
                value: _selectedExercise,
                items: _exercises
                    .map(
                      (e) => DropdownMenuItem<int>(
                        value: e['id'] as int,
                        child: Text(e['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (id) => setState(() => _selectedExercise = id),
              ),
              Column(
                //改成帶有 `+/-` 的 `Row` + `OutlinedButton`
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NumberRow(
                    label: '次數',
                    valueText: reps.toString(),
                    onMinus: () =>
                        setState(() => reps = (reps - 1).clamp(0, 999)),
                    onPlus: () =>
                        setState(() => reps = (reps + 1).clamp(0, 999)),
                    onSubmitted: (v) =>
                        setState(() => reps = int.tryParse(v) ?? reps),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),

                  const SizedBox(width: 8),
                  NumberRow(
                    label: '重量 (kg)',
                    valueText: weight.toStringAsFixed(1),
                    onMinus: () =>
                        setState(() => weight = (weight - 0.5).clamp(0, 999)),
                    onPlus: () =>
                        setState(() => weight = (weight + 0.5).clamp(0, 999)),
                    onSubmitted: (v) =>
                        setState(() => weight = double.tryParse(v) ?? weight),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,1}'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(40),
                ),
                onPressed: _isTiming ? null : _startWorkout,
                child: Text(_isTiming ? '$_remainingSeconds' : '開始'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) => setState(() {
          _navIndex = i;
          switch (_navIndex) {
            case 0:
              // Navigate to Timer Page
              _showTimerDialog();
              break;
            case 1:
              // Navigate to Report Page
              Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportPage()),
              );
              break;
            case 2:
              // Navigate to Settings Page
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
      /*
      bottomNavigationBar: AbsorbPointer(
        absorbing: _isTiming,
        child: BottomAppBar(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: _showTimerDialog,
                icon: const Icon(Icons.timer),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ReportPage()),
                  );
                },
                icon: const Icon(Icons.assessment),
              ),
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ExerciseSettingsPage(),
                    ),
                  ).then((_) => _loadData());
                },
                icon: const Icon(Icons.settings),
              ),
            ],
          ),
        ),
      ),
      */
    );
  }
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
  });

  final String label;
  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final ValueChanged<String> onSubmitted;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;

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
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(widget.label, style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            OutlinedButton(
              onPressed: widget.onMinus,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              child: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: TextField(
                controller: _c,
                textAlign: TextAlign.center,
                keyboardType: widget.keyboardType,
                inputFormatters: widget.inputFormatters,
                onSubmitted: widget.onSubmitted,
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            const SizedBox(width: 8),
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
