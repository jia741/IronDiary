import 'package:flutter/material.dart';
import 'database_helper.dart';

class ExerciseSettingsPage extends StatefulWidget {
  const ExerciseSettingsPage({super.key});

  @override
  State<ExerciseSettingsPage> createState() => _ExerciseSettingsPageState();
}

class _ExerciseSettingsPageState extends State<ExerciseSettingsPage> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _exercises = [];
  int? _selectedCategory;

  String get _currentCategoryName {
    final cat = _categories.firstWhere(
      (c) => c['id'] == _selectedCategory,
      orElse: () => {'name': ''},
    );
    return (cat['name'] as String?) ?? '';
  }

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
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
    });
  }

  Future<void> _loadExercises(int catId) async {
    final exs = await _db.getExercises(catId);
    setState(() {
      _selectedCategory = catId;
      _exercises = exs;
    });
  }

  void _showCategoryDialog({int? id, String? name}) {
    final controller = TextEditingController(text: name ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(id == null ? '新增類別' : '修改類別'),
          content: TextField(controller: controller),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (id == null) {
                  await _db.insertCategory(controller.text);
                } else {
                  await _db.updateCategory(id, controller.text);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                _loadCategories();
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  void _showExerciseDialog({int? id, String? name}) {
    if (_selectedCategory == null) return;
    final controller = TextEditingController(text: name ?? '');
    showDialog(
      context: context,
      builder: (context) {
        final catName = _currentCategoryName;
        return AlertDialog(
          title: Text('${id == null ? '新增' : '修改'}動作（$catName）'),
          content: TextField(controller: controller),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (id == null) {
                  await _db.insertExercise(_selectedCategory!, controller.text);
                } else {
                  await _db.updateExercise(id, controller.text);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
                if (!mounted) return;
                _loadExercises(_selectedCategory!);
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
    return Scaffold(
      appBar: AppBar(title: const Text('動作設定')),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: _categories
                        .map(
                          (c) => ListTile(
                            title: Text(
                              c['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            selected: c['id'] == _selectedCategory,
                            onTap: () => _loadExercises(c['id'] as int),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showCategoryDialog(
                                      id: c['id'] as int, name: c['name'] as String),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await _db.deleteCategory(c['id'] as int);
                                    _loadCategories();
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                FilledButton(
                  onPressed: () => _showCategoryDialog(),
                  child: const Text('新增類別'),
                )
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    '當前類別: $_currentCategoryName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: _exercises
                        .map(
                          (e) => ListTile(
                            title: Text(
                              e['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () => _showExerciseDialog(
                                      id: e['id'] as int, name: e['name'] as String),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    await _db.deleteExercise(e['id'] as int);
                                    _loadExercises(_selectedCategory!);
                                  },
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                FilledButton(
                  onPressed: () => _showExerciseDialog(),
                  child: const Text('新增動作'),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
