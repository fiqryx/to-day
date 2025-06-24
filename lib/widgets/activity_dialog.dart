// ignore_for_file: unused_element

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:today/helpers/notification.dart';
import 'package:today/helpers/utils.dart';
import 'package:today/stores/app_store.dart';
import 'package:today/widgets/list_sheet.dart';
import '../models/activity.dart';
import '../services/activity_service.dart';

class AddActivityDialog extends StatefulWidget {
  final DateTime date;
  final Activity? activity;

  const AddActivityDialog({
    super.key,
    required this.date,
    this.activity,
  });

  @override
  State<AddActivityDialog> createState() => _AddActivityDialogState();
}

class _AddActivityDialogState extends State<AddActivityDialog> {
  late ActivityService _activityService;
  late AppStore _appStore;

  final _formKey = GlobalKey<ShadFormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedPriority = 'medium';
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isLoading = false;
  List<GlobalKey> _tileKeys = [];

  String _sound = "Default system";
  final List<String> _soundList = [
    "Silent",
    "Default system",
    "Sound 1",
    "Sound 2",
    "Sound 3",
    "Sound 4",
    "Sound 5",
    "Sound 6",
    "Sound 7"
  ];

  @override
  void initState() {
    super.initState();
    _tileKeys = List.generate(_soundList.length, (_) => GlobalKey());

    if (widget.activity != null) {
      _titleController.text = widget.activity!.title;
      _descriptionController.text = widget.activity!.description ?? '';
      _selectedPriority = widget.activity!.priority;
      final timeParts = widget.activity!.time.split(':');
      _selectedTime = TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appStore = Provider.of<AppStore>(context);
    _activityService = Provider.of<ActivityService>(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) => Theme(
        data: Theme.of(context),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _saveActivity() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final timeString =
          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';

      if (widget.activity == null) {
        final activity = await _activityService.create(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          date: widget.date,
          time: timeString,
          priority: _selectedPriority,
        );

        await _scheduleNotification(activity);

        if (!mounted) return;
        Navigator.pop(context, activity);
      } else {
        final updatedActivity = widget.activity!.copyWith(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          time: timeString,
          priority: _selectedPriority,
        );
        await _activityService.update(updatedActivity);

        var notifId = updatedActivity.id.hashCode.abs() % 2147483647;
        await Notif.cancel(notifId);
        await _scheduleNotification(updatedActivity);

        if (!mounted) return;
        Navigator.pop(context, updatedActivity);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleNotification(Activity activity) async {
    final scheduledDate = activity.dateTime;
    if (scheduledDate.isAfter(DateTime.now()) && _appStore.reminder) {
      await Notif.createScheduleNewNotification(
        date: scheduledDate,
        content: NotificationContent(
          id: activity.id.hashCode.abs() % 2147483647,
          channelKey: "basic_channel",
          title: Utils.getActivityNotificationTitle(
              activity.priority, activity.title),
          body:
              "You scheduled this for ${DateFormat('MMM d, h:mm a').format(scheduledDate)}",
          payload: {
            'activityId': activity.id,
            'type': 'reminder',
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.input),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.activity == null ? 'Add Activity' : 'Edit Activity',
                    style: theme.textTheme.large.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            // Scrollable Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ShadForm(
                  key: _formKey,
                  child: Column(
                    children: [
                      ShadInputFormField(
                        controller: _titleController,
                        placeholder: const Text('Enter title'),
                        // description: const Text('This is your activity title.'),
                        validator: (value) => value.trim().isEmpty
                            ? 'The title is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      ShadInputFormField(
                        controller: _descriptionController,
                        placeholder: const Text('Description (Optional)'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      _TimePickerTile(
                        time: _selectedTime,
                        onTap: _selectTime,
                      ),
                      const SizedBox(height: 16),
                      _PrioritySelector(
                        selectedPriority: _selectedPriority,
                        onChanged: (value) =>
                            setState(() => _selectedPriority = value),
                      ),
                      // const SizedBox(height: 16),
                      // _AlarmSelector(title: Text(_sound), onClick: _showSheet),
                    ],
                  ),
                ),
              ),
            ),
            // Fixed Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadButton(
                      onPressed: _isLoading ? null : _saveActivity,
                      child: _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            )
                          : Text(widget.activity == null ? 'Add' : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final colorScheme = ShadTheme.of(context).colorScheme;

        return ListSheetWidget(
          title: "Alarm Sound",
          selected: _sound,
          values: _soundList,
          tileKeys: _tileKeys,
          onChanged: (selected) {
            setState(() => _sound = selected);
          },
          trailing: (value, active) {
            if (!active) return null;
            return Material(
              shape: const CircleBorder(),
              color: colorScheme.primary,
              clipBehavior: Clip.hardEdge,
              child: InkWell(
                onTap: () => debugPrint('Clicked $active'),
                radius: 16,
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: Icon(
                    size: 12,
                    LucideIcons.check,
                    color: colorScheme.primaryForeground,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePickerTile({
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 20),
            const SizedBox(width: 16),
            Text('Time', style: theme.textTheme.small),
            const Spacer(),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrioritySelector extends StatelessWidget {
  final String selectedPriority;
  final ValueChanged<String> onChanged;

  const _PrioritySelector({
    required this.selectedPriority,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final priorities = [
      {'value': 'low', 'label': 'Low', 'color': Colors.green},
      {'value': 'medium', 'label': 'Medium', 'color': Colors.orange},
      {'value': 'high', 'label': 'High', 'color': Colors.red},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Priority',
          style: theme.textTheme.muted.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: priorities.map((priority) {
            final isSelected = selectedPriority == priority['value'];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onChanged(priority['value'] as String),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (priority['color'] as Color).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? priority['color'] as Color
                            : theme.colorScheme.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        priority['label'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? priority['color'] as Color
                              : theme.colorScheme.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AlarmSelector extends StatelessWidget {
  final Widget? title;
  final void Function()? onClick;

  // ignore: unused_element_parameter
  const _AlarmSelector({this.title, this.onClick});

  @override
  Widget build(BuildContext context) {
    var theme = ShadTheme.of(context);
    return ListTile(
      title: title,
      onTap: onClick,
      leading: Transform.scale(
        scale: 0.8,
        child: const Icon(LucideIcons.bellRing),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.input),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      trailing: IconButton(
        onPressed: onClick,
        padding: EdgeInsets.zero,
        icon: const Icon(size: 16, LucideIcons.chevronDown),
      ),
    );
  }
}
