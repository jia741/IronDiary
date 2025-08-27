import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'database_helper.dart';

class ExerciseSettingsPage extends StatefulWidget {
  const ExerciseSettingsPage({super.key});

  @override
  State<ExerciseSettingsPage> createState() => _ExerciseSettingsPageState();
}

class _ExerciseSettingsPageState extends State<ExerciseSettingsPage> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _db.getCategories();
    final List<Map<String, dynamic>> withExs = [];
    for (final c in cats) {
      final exs = await _db.getExercises(c['id'] as int);
      withExs.add({...c, 'exercises': exs});
    }
    setState(() {
      _categories = withExs;
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
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

  void _showExerciseDialog(int catId, String catName, {int? id, String? name}) {
    final controller = TextEditingController(text: name ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${id == null ? '新增' : '修改'}動作（$catName）'),
          content: TextField(controller: controller),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (id == null) {
                  await _db.insertExercise(catId, controller.text);
                } else {
                  await _db.updateExercise(id, controller.text);
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

  Widget _buildExerciseTile(int catId, String catName, Map<String, dynamic> e) {
    return Slidable(
      key: ValueKey('ex_${e['id']}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) =>
                _showExerciseDialog(catId, catName, id: e['id'] as int, name: e['name'] as String),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: '編輯',
          ),
          SlidableAction(
            onPressed: (context) async {
              await _db.deleteExercise(e['id'] as int);
              _loadCategories();
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '刪除',
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          e['name'] as String,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> c) {
    final catId = c['id'] as int;
    final catName = c['name'] as String;
    final exercises = c['exercises'] as List<Map<String, dynamic>>;
    return Slidable(
      key: ValueKey('cat_$catId'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) =>
                _showCategoryDialog(id: catId, name: catName),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: '編輯',
          ),
          SlidableAction(
            onPressed: (context) async {
              await _db.deleteCategory(catId);
              _loadCategories();
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '刪除',
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          catName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          ...exercises
              .map((e) => _buildExerciseTile(catId, catName, e))
              .toList(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _showExerciseDialog(catId, catName),
              icon: const Icon(Icons.add),
              label: const Text('新增動作'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('動作設定')),
      body: ListView(
        children: [
          ..._categories.map(_buildCategoryTile).toList(),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: () => _showCategoryDialog(),
              child: const Text('新增類別'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
