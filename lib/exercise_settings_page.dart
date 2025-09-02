import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'database_helper.dart';
import 'screen_util.dart';

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
      // Convert the query result to a modifiable list. Sqflite's QueryResultSet
      // is read-only and attempting to modify it (e.g. during reordering)
      // will throw an UnsupportedError.
      final exs = List<Map<String, dynamic>>.from(
          await _db.getExercises(c['id'] as int));
      withExs.add({...c, 'exercises': exs});
    }
    setState(() {
      _categories = withExs;
    });
  }

  void _reorderCategories(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);
    });
  }

  void _reorderExercises(int catId, int oldIndex, int newIndex) {
    setState(() {
      final exercises = _categories
          .firstWhere((c) => c['id'] == catId)['exercises']
          as List<Map<String, dynamic>>;
      if (newIndex > oldIndex) newIndex -= 1;
      final item = exercises.removeAt(oldIndex);
      exercises.insert(newIndex, item);
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
                try {
                  final name = controller.text.trim();
                  if (id == null) {
                    await _db.insertCategory(name);
                  } else {
                    await _db.updateCategory(id, name);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (!mounted) return;
                  _loadCategories();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('類別名稱重複')));
                }
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
                try {
                  final name = controller.text.trim();
                  if (id == null) {
                    await _db.insertExercise(catId, name);
                  } else {
                    await _db.updateExercise(id, name);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (!mounted) return;
                  _loadCategories();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('動作名稱重複')));
                }
              },
              child: const Text('確定'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExerciseTile(
      int catId, String catName, Map<String, dynamic> e, int index) {
    return Slidable(
      key: ValueKey('ex_${e['id']}'),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _showExerciseDialog(
                catId, catName,
                id: e['id'] as int, name: e['name'] as String),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: '編輯',
          ),
          SlidableAction(
            onPressed: (context) async {
              final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('確認刪除'),
                      content:
                          Text("確定要刪除『${e['name']}』這個動作嗎？"),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('取消')),
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, true),
                            child: const Text('刪除')),
                      ],
                    ),
                  ) ??
                  false;
              if (confirm) {
                await _db.deleteExercise(e['id'] as int);
                _loadCategories();
              }
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '刪除',
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.symmetric(
            horizontal: ScreenUtil.w(8), vertical: ScreenUtil.h(4)),
        child: ListTile(
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          title: Text(
            e['name'] as String,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> c, int index) {
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
              final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('確認刪除'),
                      content: Text(
                          "確定要刪除『$catName』這個類別嗎？所有相關動作將一併被刪除。"),
                      actions: [
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('取消')),
                        TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, true),
                            child: const Text('刪除')),
                      ],
                    ),
                  ) ??
                  false;
              if (confirm) {
                await _db.deleteCategory(catId);
                _loadCategories();
              }
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '刪除',
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.symmetric(
            horizontal: ScreenUtil.w(8), vertical: ScreenUtil.h(4)),
        child: ExpansionTile(
          leading: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle),
          ),
          title: Text(
            catName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (oldIndex, newIndex) =>
                  _reorderExercises(catId, oldIndex, newIndex),
              buildDefaultDragHandles: false,
              children: [
                for (int i = 0; i < exercises.length; i++)
                  _buildExerciseTile(catId, catName, exercises[i], i),
              ],
            ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('動作設定')),
      body: SafeArea(
        child: _categories.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline,
                        size: ScreenUtil.w(80), color: Colors.grey),
                    SizedBox(height: ScreenUtil.h(16)),
                    const Text('您尚未建立任何動作類別，點擊下方按鈕開始吧！'),
                    SizedBox(height: ScreenUtil.h(16)),
                    ElevatedButton(
                      onPressed: () => _showCategoryDialog(),
                      child: const Text('新增類別'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ReorderableListView(
                      onReorder: _reorderCategories,
                      buildDefaultDragHandles: false,
                      children: [
                        for (int i = 0; i < _categories.length; i++)
                          _buildCategoryTile(_categories[i], i),
                      ],
                    ),
                  ),
                  SizedBox(height: ScreenUtil.h(16)),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _showCategoryDialog(),
                      child: const Text('新增類別'),
                    ),
                  ),
                  SizedBox(height: ScreenUtil.h(16)),
                ],
              ),
      ),
    );
  }
}
