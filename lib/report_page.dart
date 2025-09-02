import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_helper.dart';

enum _Range { days30, days90, year }

enum _DistRange { days30, days60, year }

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
    final data = await _db.getWorkouts(
        DateTime.fromMillisecondsSinceEpoch(0), DateTime.now());
    setState(() => _allWorkouts = data);
    _computeDistribution();
  }

  void _onCategoryChanged(int? id) async {
    setState(() {
      _selectedCategoryId = id;
      _selectedExerciseId = null;
      _exercises = [];
    });
    if (id != null) {
      final exs = await _db.getExercises(id);
      setState(() => _exercises = exs);
    }
    _updateChartData();
    _computeDistribution();
  }

  void _onExerciseChanged(int? id) {
    setState(() => _selectedExerciseId = id);
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
        _distRange = _DistRange.days60;
      } else if (_distRange == _DistRange.days60) {
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
      case _DistRange.days60:
        return '近60天';
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
        double weight = (w['weight'] as num).toDouble();
        final unit = w['unit'] as String;
        if (unit.toLowerCase() == 'lb') {
          weight *= 0.453592;
        }
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
      double weight = (w['weight'] as num).toDouble();
      final unit = w['unit'] as String;
      if (unit.toLowerCase() == 'lb') {
        weight *= 0.453592;
      }
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
      case _DistRange.days60:
        start = now.subtract(const Duration(days: 59));
        break;
      case _DistRange.year:
        start = now.subtract(const Duration(days: 364));
        break;
    }

    final Map<String, double> totals = {};
    for (final w in _allWorkouts) {
      final ts = DateTime.fromMillisecondsSinceEpoch(w['timestamp'] as int);
      if (ts.isBefore(start) || ts.isAfter(now)) continue;
      double weight = (w['weight'] as num).toDouble();
      final unit = w['unit'] as String;
      if (unit.toLowerCase() == 'lb') {
        weight *= 0.453592;
      }
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
          style: const TextStyle(fontSize: 10));
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
                                        style: const TextStyle(fontSize: 10),
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
                                  spots: _spots,
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
        const SizedBox(height: 8),
        TextButton(onPressed: _cycleDistRange, child: Text(_distRangeLabel())),
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
                    titleStyle: const TextStyle(fontSize: 12),
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
              final date =
                  DateTime.fromMillisecondsSinceEpoch(w['timestamp'] as int);
              final weight = (w['weight'] as num).toDouble();
              final unit = w['unit'] as String;
              return ListTile(
                title: Text('${w['category_name']} - ${w['exercise_name']}'),
                subtitle: Text(
                  '${date.toLocal()}  次數:${w['reps']}  重量:${weight.toStringAsFixed(1)}$unit  休息:${w['rest_seconds']}秒',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

