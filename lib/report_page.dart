import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import 'database_helper.dart';
import 'screen_util.dart';

enum _Range { days30, days90, year }

enum _DistRange { days30, days90, year }

double _toKg(double weight, String unit) {
  return unit.toLowerCase() == 'lb' ? weight * 0.453592 : weight;
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final _db = DatabaseHelper.instance;
  _Range _range = _Range.days30;
  _DistRange _distRange = _DistRange.days30;
  int? _selectedCategoryId;
  int? _selectedExerciseId;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _allWorkouts = [];

  List<FlSpot> _spots = [];
  List<String> _labels = [];
  double _maxY = 0;
  final ScrollController _chartController = ScrollController();
  bool _shouldScrollToEnd = true;

  Map<String, double> _distTotals = {};

  @override
  void initState() {
    super.initState();
    Future(() async {
      await _loadSelections();
      await _loadAllWorkouts();
      _updateChartData();
      _computeDistribution();
    });
  }

  @override
  void dispose() {
    _chartController.dispose();
    super.dispose();
  }

  Future<void> _loadSelections() async {
    final prefs = await SharedPreferences.getInstance();
    final cats = await _db.getCategories();
    int? catId = prefs.getInt('selectedCategory');
    int? exId = prefs.getInt('selectedExercise');
    List<Map<String, dynamic>> exs = [];
    if (catId != null && cats.any((c) => c['id'] == catId)) {
      exs = await _db.getExercises(catId);
    } else {
      catId = null;
    }
    if (exId != null && !exs.any((e) => e['id'] == exId)) {
      exId = null;
    }
    setState(() {
      _categories = cats;
      _selectedCategoryId = catId;
      _exercises = exs;
      _selectedExerciseId = exId;
    });
  }

  Future<void> _loadAllWorkouts() async {
    final now = DateTime.now();
    DateTime startRange;
    switch (_range) {
      case _Range.days30:
        startRange = now.subtract(const Duration(days: 29));
        break;
      case _Range.days90:
        startRange = now.subtract(const Duration(days: 89));
        break;
      case _Range.year:
        startRange = DateTime(now.year, now.month - 11, 1);
        break;
    }
    DateTime startDist;
    switch (_distRange) {
      case _DistRange.days30:
        startDist = now.subtract(const Duration(days: 29));
        break;
      case _DistRange.days90:
        startDist = now.subtract(const Duration(days: 89));
        break;
      case _DistRange.year:
        startDist = now.subtract(const Duration(days: 364));
        break;
    }
    final start = startRange.isBefore(startDist) ? startRange : startDist;
    final data = await _db.getWorkouts(start, now);
    setState(() => _allWorkouts = data);
    _computeDistribution();
  }

  void _onCategoryChanged(int? id) async {
    setState(() {
      _selectedCategoryId = id;
      _selectedExerciseId = null;
      _exercises = [];
    });
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setInt('selectedCategory', id);
      await prefs.remove('selectedExercise');
      final exs = await _db.getExercises(id);
      setState(() => _exercises = exs);
    } else {
      await prefs.remove('selectedCategory');
      await prefs.remove('selectedExercise');
    }
    _updateChartData();
    _computeDistribution();
  }

  void _onExerciseChanged(int? id) async {
    setState(() => _selectedExerciseId = id);
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setInt('selectedExercise', id);
    } else {
      await prefs.remove('selectedExercise');
    }
    _updateChartData();
  }

  void _cycleRange() {
    setState(() {
      if (_range == _Range.days30) {
        _range = _Range.days90;
      } else if (_range == _Range.days90) {
        _range = _Range.year;
      } else {
        _range = _Range.days30;
      }
    });
    _updateChartData();
  }

  void _cycleDistRange() {
    setState(() {
      if (_distRange == _DistRange.days30) {
        _distRange = _DistRange.days90;
      } else if (_distRange == _DistRange.days90) {
        _distRange = _DistRange.year;
      } else {
        _distRange = _DistRange.days30;
      }
    });
    _computeDistribution();
  }

  String _rangeLabel() {
    switch (_range) {
      case _Range.days30:
        return '近30天';
      case _Range.days90:
        return '近90天';
      case _Range.year:
        return '近一年';
    }
  }

  String _distRangeLabel() {
    switch (_distRange) {
      case _DistRange.days30:
        return '近30天';
      case _DistRange.days90:
        return '近90天';
      case _DistRange.year:
        return '近一年';
    }
  }

  String _catName(int id) =>
      _categories.firstWhere((c) => c['id'] == id)['name'] as String;

  void _updateChartData() {
    final latest = _allWorkouts.isEmpty
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(_allWorkouts
            .map<int>((w) => w['timestamp'] as int)
            .reduce(math.max));
    final now = latest;
    DateTime start;
    int groups = 0;
    switch (_range) {
      case _Range.days30:
        start = now.subtract(const Duration(days: 29));
        break;
      case _Range.days90:
        start = now.subtract(const Duration(days: 89));
        groups = 13;
        break;
      case _Range.year:
        start = DateTime(now.year, now.month - 11, 1);
        groups = 12;
        break;
    }

    if (_range == _Range.days30) {
      final Map<DateTime, double> volumes = {};
      for (final w in _allWorkouts) {
        final ts =
            DateTime.fromMillisecondsSinceEpoch(w['timestamp'] as int);
        if (ts.isBefore(start) || ts.isAfter(now)) continue;
        if (_selectedCategoryId != null &&
            w['category_name'] != _catName(_selectedCategoryId!)) {
          continue;
        }
        if (_selectedExerciseId != null) {
          final exName = _exercises
              .firstWhere((e) => e['id'] == _selectedExerciseId)['name']
              as String;
          if (w['exercise_name'] != exName) continue;
        }
        final weight =
            _toKg((w['weight'] as num).toDouble(), w['unit'] as String);
        final reps = w['reps'] as int;
        final vol = weight * reps;
        final day = DateTime(ts.year, ts.month, ts.day);
        volumes[day] = (volumes[day] ?? 0) + vol;
      }
      final dates = volumes.keys.toList()..sort();
      final spots = <FlSpot>[];
      final labels = <String>[];
      for (var i = 0; i < dates.length; i++) {
        final d = dates[i];
        final y = volumes[d] ?? 0;
        spots.add(FlSpot(i.toDouble(), y));
        labels.add('${d.month}/${d.day}');
      }
      final maxY = spots.fold<double>(0, (p, s) => math.max(p, s.y));
      setState(() {
        _spots = spots;
        _labels = labels;
        _maxY = maxY;
        _shouldScrollToEnd = true;
      });
      return;
    }

    final Map<int, double> volumes = {for (var i = 0; i < groups; i++) i: 0};
    for (final w in _allWorkouts) {
      final ts =
          DateTime.fromMillisecondsSinceEpoch(w['timestamp'] as int);
      if (ts.isBefore(start) || ts.isAfter(now)) continue;
      if (_selectedCategoryId != null &&
          w['category_name'] != _catName(_selectedCategoryId!)) {
        continue;
      }
      if (_selectedExerciseId != null) {
        final exName = _exercises
            .firstWhere((e) => e['id'] == _selectedExerciseId)['name']
            as String;
        if (w['exercise_name'] != exName) continue;
      }
      final weight =
          _toKg((w['weight'] as num).toDouble(), w['unit'] as String);
      final reps = w['reps'] as int;
      final vol = weight * reps;
      int idx;
      switch (_range) {
        case _Range.days90:
          idx = ts.difference(start).inDays ~/ 7;
          break;
        case _Range.year:
          idx = (ts.year - start.year) * 12 + ts.month - start.month;
          break;
        default:
          idx = 0;
      }
      volumes[idx] = (volumes[idx] ?? 0) + vol;
    }
    final List<FlSpot> spots = [];
    final List<String> labels = [];
    for (int i = 0; i < groups; i++) {
      final y = volumes[i] ?? 0;
      spots.add(FlSpot(i.toDouble(), y));
      DateTime d;
      switch (_range) {
        case _Range.days90:
          d = start.add(Duration(days: i * 7));
          labels.add('${d.month}/${d.day}');
          break;
        case _Range.year:
          d = DateTime(start.year, start.month + i);
          labels.add('${d.month}月');
          break;
        default:
          break;
      }
    }
    final maxY = spots.fold<double>(0, (p, s) => math.max(p, s.y));
    setState(() {
      _spots = spots;
      _labels = labels;
      _maxY = maxY;
      _shouldScrollToEnd = true;
    });
  }

  void _computeDistribution() {
    final latest = _allWorkouts.isEmpty
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(
            _allWorkouts.map<int>((w) => w['timestamp'] as int).reduce(math.max));
    final now = latest;
    DateTime start;
    switch (_distRange) {
      case _DistRange.days30:
        start = now.subtract(const Duration(days: 29));
        break;
      case _DistRange.days90:
        start = now.subtract(const Duration(days: 89));
        break;
      case _DistRange.year:
        start = now.subtract(const Duration(days: 364));
        break;
    }

    final Map<String, double> totals = {};
    for (final w in _allWorkouts) {
      final ts = DateTime.fromMillisecondsSinceEpoch(w['timestamp'] as int);
      if (ts.isBefore(start) || ts.isAfter(now)) continue;
      final weight =
          _toKg((w['weight'] as num).toDouble(), w['unit'] as String);
      final reps = w['reps'] as int;
      final vol = weight * reps;
      if (_selectedCategoryId == null) {
        final c = w['category_name'] as String;
        totals[c] = (totals[c] ?? 0) + vol;
      } else {
        final cName = _catName(_selectedCategoryId!);
        if (w['category_name'] != cName) continue;
        final e = w['exercise_name'] as String;
        totals[e] = (totals[e] ?? 0) + vol;
      }
    }
    setState(() => _distTotals = totals);
  }

  List<Map<String, dynamic>> _filteredRecords() {
    final data = _allWorkouts.where((w) {
      if (_selectedCategoryId != null &&
          w['category_name'] != _catName(_selectedCategoryId!)) {
        return false;
      }
      if (_selectedExerciseId != null) {
        final exName = _exercises
            .firstWhere((e) => e['id'] == _selectedExerciseId)['name']
            as String;
        if (w['exercise_name'] != exName) return false;
      }
      return true;
    }).toList();
    data.sort((a, b) =>
        (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    return data;
  }

  Widget _buildYAxis() {
    final labels = List.generate(5, (i) {
      final val = (_maxY / 4 * (4 - i));
      return Text(val.toStringAsFixed(0),
          style: TextStyle(fontSize: ScreenUtil.sp(10)));
    });
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('報表'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '趨勢'),
              Tab(text: '分布'),
              Tab(text: '紀錄'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _buildTrendTab(),
              _buildDistributionTab(),
              _buildRecordTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendTab() {
    return Column(
      children: [
        TextButton(onPressed: _cycleRange, child: Text(_rangeLabel())),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButton<int?>(
              hint: const Text('部位'),
              value: _selectedCategoryId,
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('全部')),
                ..._categories.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c['id'] as int,
                    child: Text(c['name'] as String),
                  ),
                ),
              ],
              onChanged: (v) => _onCategoryChanged(v),
            ),
            const SizedBox(width: 16),
            DropdownButton<int?>(
              hint: const Text('動作'),
              value: _selectedExerciseId,
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('全部')),
                ..._exercises.map(
                  (e) => DropdownMenuItem<int?>(
                    value: e['id'] as int,
                    child: Text(e['name'] as String),
                  ),
                ),
              ],
              onChanged:
                  _selectedCategoryId == null ? null : (v) => _onExerciseChanged(v),
            ),
          ],
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const yAxisWidth = 40.0;
                final maxWidth = constraints.maxWidth - yAxisWidth;
                final chartWidth =
                    _spots.length <= 6 ? maxWidth : maxWidth / 6 * _spots.length;
                if (_shouldScrollToEnd) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_chartController.hasClients) {
                      _chartController
                          .jumpTo(_chartController.position.maxScrollExtent);
                    }
                  });
                  _shouldScrollToEnd = false;
                }
                return Row(
                  children: [
                    SizedBox(width: yAxisWidth, child: _buildYAxis()),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _chartController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: _spots.isNotEmpty
                                  ? (_spots.length - 1).toDouble()
                                  : 0,
                              minY: 0,
                              maxY: _maxY == 0 ? 1 : _maxY,
                              titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= _labels.length) {
                                      return const SizedBox();
                                    }
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      fitInside:
                                          SideTitleFitInsideData.fromTitleMeta(
                                              meta),
                                      child: Text(
                                        _labels[index],
                                        style: TextStyle(fontSize: ScreenUtil.sp(10)),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                  sideTitles: SideTitles(showTitles: false)),
                                topTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                                rightTitles: AxisTitles(
                                    sideTitles: SideTitles(showTitles: false)),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _spots.isEmpty ? [FlSpot(0, 0)] : _spots, //如果還未有資料，避免錯誤
                                  isCurved: false,
                                  color: Colors.blue,
                                  barWidth: 3,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionTab() {
    final entries = _distTotals.entries.toList();
    final total = entries.fold<double>(0, (p, e) => p + e.value);
    return Column(
      children: [
        TextButton(onPressed: _cycleDistRange, child: Text(_distRangeLabel())),
        const SizedBox(height: 8),
        DropdownButton<int?>(
          hint: const Text('部位'),
          value: _selectedCategoryId,
          items: [
            const DropdownMenuItem<int?> (
                value: null, child: Text('全部')),
            ..._categories.map(
              (c) => DropdownMenuItem<int?> (
                value: c['id'] as int,
                child: Text(c['name'] as String),
              ),
            ),
          ],
          onChanged: (v) => _onCategoryChanged(v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                sections: entries.asMap().entries.map((entry) {
                  final index = entry.key;
                  final e = entry.value;
                  final color =
                      Colors.primaries[index % Colors.primaries.length];
                  return PieChartSectionData(
                    value: e.value,
                    color: color,
                    title: e.key,
                    radius: 60,
                    titleStyle: TextStyle(fontSize: ScreenUtil.sp(12)),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('名稱')),
                DataColumn(label: Text('百分比')),
                DataColumn(label: Text('總訓練量')),
              ],
              rows: entries.map((e) {
                final percent = total == 0 ? 0 : e.value / total * 100;
                return DataRow(cells: [
                  DataCell(Text(e.key)),
                  DataCell(Text('${percent.toStringAsFixed(1)}%')),
                  DataCell(Text('${e.value.toStringAsFixed(1)}kg')),
                ]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordTab() {
    final records = _filteredRecords();
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DropdownButton<int?>(
              hint: const Text('部位'),
              value: _selectedCategoryId,
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('全部')),
                ..._categories.map((c) => DropdownMenuItem<int?>(
                      value: c['id'] as int,
                      child: Text(c['name'] as String),
                    )),
              ],
              onChanged: (v) => _onCategoryChanged(v),
            ),
            const SizedBox(width: 16),
            DropdownButton<int?>(
              hint: const Text('動作'),
              value: _selectedExerciseId,
              items: [
                const DropdownMenuItem<int?>(
                    value: null, child: Text('全部')),
                ..._exercises.map((e) => DropdownMenuItem<int?>(
                      value: e['id'] as int,
                      child: Text(e['name'] as String),
                    )),
              ],
              onChanged:
                  _selectedCategoryId == null ? null : (v) => _onExerciseChanged(v),
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final w = records[index];
              final date = DateTime.fromMillisecondsSinceEpoch(w['timestamp'] as int);
              final dateStr = date.toLocal().toString().split('.').first;
              final weight = (w['weight'] as num).toDouble();
              final unit = w['unit'] as String;
              return Slidable(
                key: ValueKey('workout_${w['id']}'),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (_) => _showEditWorkoutDialog(w),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.edit,
                      label: '編輯',
                    ),
                    SlidableAction(
                      onPressed: (_) async {
                        final confirm = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('確認刪除'),
                                content: const Text('確定要刪除這筆紀錄嗎？'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, false),
                                    child: const Text('取消'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(dialogContext, true),
                                    child: const Text('刪除'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (confirm) {
                          await _db.deleteWorkout(w['id'] as int);
                          await _loadAllWorkouts();
                          _updateChartData();
                        }
                      },
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: '刪除',
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text('${w['category_name']} - ${w['exercise_name']}'),
                  subtitle: Text(
                    '$dateStr  次數:${w['reps']}  重量:${weight.toStringAsFixed(1)}$unit  休息:${w['rest_seconds']}秒',
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showEditWorkoutDialog(Map<String, dynamic> w) async {
    final id = w['id'] as int;
    final repsController = TextEditingController(text: (w['reps'] as int).toString());
    final weightController = TextEditingController(text: (w['weight'] as num).toString());
    final restController = TextEditingController(text: (w['rest_seconds'] as int).toString());
    String unit = (w['unit'] as String);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('編輯紀錄'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${w['category_name']} - ${w['exercise_name']}'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: repsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '次數'),
                    ),
                    TextField(
                      controller: weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: '重量'),
                    ),
                    Row(
                      children: [
                        const Text('單位: '),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: unit,
                          items: const [
                            DropdownMenuItem(value: 'kg', child: Text('kg')),
                            DropdownMenuItem(value: 'lb', child: Text('lb')),
                          ],
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => unit = v);
                          },
                        ),
                      ],
                    ),
                    TextField(
                      controller: restController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '休息秒數'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {
                    final reps = int.tryParse(repsController.text.trim());
                    final weight = double.tryParse(weightController.text.trim());
                    final rest = int.tryParse(restController.text.trim());
                    if (reps == null || weight == null || rest == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('請輸入有效的數值')),
                      );
                      return;
                    }
                    await _db.updateWorkout(
                      id: id,
                      reps: reps,
                      weight: weight,
                      unit: unit,
                      restSeconds: rest,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    await _loadAllWorkouts();
                    _updateChartData();
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
