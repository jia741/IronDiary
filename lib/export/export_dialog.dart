import 'package:flutter/material.dart';

/// A minimal dialog that streams export data and guards against empty snapshots.
class ExportDialog extends StatelessWidget {
  const ExportDialog({super.key, required this.stream});

  /// Stream of lines to export.
  final Stream<List<String>> stream;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: StreamBuilder<List<String>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final data = snapshot.data;
          if (data == null || data.isEmpty) {
            // Avoid calling `first` on an empty list which previously caused a
            // `StateError`.
            return const SizedBox(
              height: 80,
              child: Center(child: Text('沒有資料可匯出')),
            );
          }

          // Safe to access the first element now that we know the list is not empty.
          final firstLine = data.first;
          return SizedBox(
            height: 80,
            child: Center(child: Text('第一筆: $firstLine')),
          );
        },
      ),
    );
  }
}

