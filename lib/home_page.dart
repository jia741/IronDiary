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
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('開始計時')));
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
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('計時完成')));
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
            FilledButton(
              onPressed: () {
                setState(() {
                  _timerSeconds = int.tryParse(controller.text) ?? _timerSeconds;
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: AbsorbPointer(
        absorbing: _isTiming,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownMenu<int>(
                initialSelection: _selectedCategory,
                dropdownMenuEntries: _categories
                    .map((c) => DropdownMenuEntry<int>(
                          value: c['id'] as int,
                          label: c['name'] as String,
                        ))
                    .toList(),
                onSelected: _onCategoryChanged,
              ),
              DropdownMenu<int>(
                initialSelection: _selectedExercise,
                dropdownMenuEntries: _exercises
                    .map((e) => DropdownMenuEntry<int>(
                          value: e['id'] as int,
                          label: e['name'] as String,
                        ))
                    .toList(),
                onSelected: (id) => setState(() => _selectedExercise = id),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _repController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '次數'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '重量(kg)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(40)),
                onPressed: _isTiming ? null : _startWorkout,
                child: Text(_isTiming ? '$_remainingSeconds' : '開始'),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AbsorbPointer(
        absorbing: _isTiming,
        child: NavigationBar(
          selectedIndex: _navIndex,
          onDestinationSelected: (index) {
            setState(() => _navIndex = index);
            switch (index) {
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
                  MaterialPageRoute(builder: (_) => const ExerciseSettingsPage()),
                ).then((_) => _loadData());
                break;
            }
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.timer), label: '計時'),
            NavigationDestination(icon: Icon(Icons.assessment), label: '報表'),
            NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
          ],
        ),
      ),
    );
  }
}
