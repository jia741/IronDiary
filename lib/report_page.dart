import 'package:flutter/material.dart';
import 'database_helper.dart';

enum _Period { day, week, month }

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  _Period _period = _Period.day;
  DateTime _anchor = DateTime.now();
  List<Map<String, dynamic>> _workouts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime get _start {
    switch (_period) {
      case _Period.day:
        return DateTime(_anchor.year, _anchor.month, _anchor.day);
      case _Period.week:
        final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        return DateTime(start.year, start.month, start.day);
      case _Period.month:
        return DateTime(_anchor.year, _anchor.month, 1);
    }
  }

  DateTime get _end {
    switch (_period) {
      case _Period.day:
        return _start.add(const Duration(days: 1));
      case _Period.week:
        return _start.add(const Duration(days: 7));
      case _Period.month:
        return DateTime(_anchor.year, _anchor.month + 1, 1);
    }
  }

  Future<void> _loadData() async {
    final data = await DatabaseHelper.instance.getWorkouts(_start, _end);
    setState(() {
      _workouts = data;
    });
  }

  void _changePeriod(_Period p) {
    setState(() {
      _period = p;
      _anchor = DateTime.now();
    });
    _loadData();
  }

  void _shift(int direction) {
    setState(() {
      switch (_period) {
        case _Period.day:
          _anchor = _anchor.add(Duration(days: direction));
          break;
        case _Period.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
          break;
        case _Period.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, _anchor.day);
          break;
      }
    });
    _loadData();
  }

  String _title() {
    switch (_period) {
      case _Period.day:
        return '${_anchor.year}-${_anchor.month}-${_anchor.day}';
      case _Period.week:
        final end = _start.add(const Duration(days: 6));
        return '${_start.month}/${_start.day} - ${end.month}/${end.day}';
      case _Period.month:
        return '${_anchor.year}-${_anchor.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('報表')),
      body: Column(
        children: [
          Center(
            child: SegmentedButton<_Period>(
              segments: const [
                ButtonSegment(value: _Period.day, label: Text('日')),
                ButtonSegment(value: _Period.week, label: Text('周')),
                ButtonSegment(value: _Period.month, label: Text('月')),
              ],
              selected: {_period},
              onSelectionChanged: (s) => _changePeriod(s.first),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.arrow_left)),
              Text(_title()),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.arrow_right)),
            ],
          ),
          Expanded(
            child: ListView(
              children: _workouts
                  .map(
                    (w) => ListTile(
                      title: Text('${w['category_name']} - ${w['exercise_name']}'),
                      subtitle:
                          Text('次數: ${w['reps']}  重量: ${w['weight']}kg'),
                    ),
                  )
                  .toList(),
            ),
          )
        ],
      ),
    );
  }
}
