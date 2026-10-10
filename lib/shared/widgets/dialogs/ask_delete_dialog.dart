import 'package:flutter/material.dart';

class AskDeleteDialog extends StatelessWidget {
  final String title;
  final String itemName;
  final String description;
  final VoidCallback onDelete;
  final String cancelText;
  final String deleteText;

  const AskDeleteDialog({
    super.key,
    required this.title,
    required this.itemName,
    required this.description,
    required this.onDelete,
    this.cancelText = 'Cancel',
    this.deleteText = 'Delete',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      // ---------- TITLE ----------
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        ],
      ),

      // ---------- CONTENT ----------
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(itemName, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),

      // ---------- ACTIONS ----------
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(cancelText)),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(deleteText),
        ),
      ],
    );
  }
}
