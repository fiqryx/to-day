import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../models/activity.dart';

class ActivityCard extends StatelessWidget {
  final Activity activity;
  final VoidCallback? onTap;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onDelete;
  final bool isReadOnly;

  const ActivityCard({
    super.key,
    required this.activity,
    this.onTap,
    this.onToggleComplete,
    this.onDelete,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return ShadCard(
      padding: const EdgeInsets.all(4),
      // margin: const EdgeInsets.only(bottom: 12),
      // elevation: 2,
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isReadOnly ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Completion Checkbox
                  GestureDetector(
                    onTap: isReadOnly ? null : onToggleComplete,
                    child: Container(
                      width: 24,
                      height: 24,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: activity.completed
                              ? Colors.green.withOpacity(0.8)
                              : theme.colorScheme.accent,
                          width: 2,
                        ),
                        color: activity.completed
                            ? Colors.green.withOpacity(0.8)
                            : Colors.transparent,
                      ),
                      child: activity.completed
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: theme.colorScheme.background,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Priority
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activity.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  decoration: activity.completed
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: activity.completed
                                      ? theme.colorScheme.mutedForeground
                                      : theme.colorScheme.foreground,
                                ),
                              ),
                            ),
                            _buildPriorityChip(activity.priority),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Time
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: theme.colorScheme.mutedForeground,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              activity.time,
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.mutedForeground,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Description
                        if (activity.description != null &&
                            activity.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            activity.description!,
                            style: TextStyle(
                              fontSize: 14,
                              color: theme.colorScheme.mutedForeground,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Action Buttons
                  if (!isReadOnly) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                            color: theme
                                .colorScheme.input), // Your existing border
                        borderRadius:
                            BorderRadius.circular(8), // Add border radius here
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            onTap?.call();
                            break;
                          case 'delete':
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 18),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      child: Icon(
                        Icons.more_vert,
                        color: theme.colorScheme.foreground.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    Color color;
    String label;

    switch (priority) {
      case 'high':
        color = Colors.red;
        label = 'High';
        break;
      case 'medium':
        color = Colors.orange;
        label = 'Medium';
        break;
      case 'low':
        color = Colors.green;
        label = 'Low';
        break;
      default:
        color = Colors.orange;
        label = 'Medium';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color.withOpacity(0.8),
        ),
      ),
    );
  }
}
