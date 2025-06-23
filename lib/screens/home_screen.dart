import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:today/helpers/utils.dart';
import 'package:today/models/activity.dart';
import 'package:today/services/activity_service.dart';
import 'package:today/widgets/activity_card.dart';
import 'package:today/widgets/activity_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ActivityService _activityService;
  late ShadColorScheme _colorScheme;

  DateTime? lastBackPressTime;
  DateTime _selectedDate = DateTime.now();
  List<Activity> _activities = [];
  Map<String, int> _stats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getData(); // load after first frame is built
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _activityService = Provider.of<ActivityService>(context);
    _colorScheme = ShadTheme.of(context).colorScheme;
  }

  Future<void> _getData() async {
    if (!mounted || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final activities = await _activityService.getByDate(_selectedDate);
      final stats = await _activityService.getStats(_selectedDate);

      setState(() {
        _activities = activities;
        _stats = stats;
      });
    } catch (e) {
      if (!mounted) return;
      _toast(ShadToast.destructive(
        title: const Text('Get activities error'),
        description: Text(e.toString()),
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onSelectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _getData();
    }
  }

  Future<void> _onCreate() async {
    final result = await showDialog<Activity>(
      context: context,
      builder: (context) => AddActivityDialog(date: _selectedDate),
    );

    if (result != null) _getData();
  }

  Future<void> _onEdit(Activity activity) async {
    final result = await showDialog<Activity>(
      context: context,
      builder: (context) => AddActivityDialog(
        date: _selectedDate,
        activity: activity,
      ),
    );
    if (result != null) _getData();
  }

  Future<void> _toggleCompletion(Activity activity) async {
    if (activity.id != null) {
      try {
        await _activityService.toggleCompleted(activity.id!);
        _getData();
      } catch (e) {
        _toast(ShadToast.destructive(
          title: const Text('Update failed'),
          description: Text(e.toString()),
        ));
      }
    }
  }

  Future<void> _onDelete(Activity activity) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _colorScheme.input),
        ),
        content: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Are you sure you want to delete "${activity.title}"?'),
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && activity.id != null) {
      try {
        await _activityService.delete(activity.id!);
        _getData();
      } catch (e) {
        _toast(ShadToast.destructive(
          title: const Text('Delete failed'),
          description: Text(e.toString()),
        ));
      }
    }
  }

  void _toast(ShadToast toast) => ShadToaster.of(context).show(toast);

  @override
  Widget build(BuildContext context) {
    final isToday = Utils.isSameDay(_selectedDate, DateTime.now());
    final isPast = _selectedDate.isBefore(DateTime.now()) && !isToday;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          dotenv.env['VAR_NAME'] ?? "ToDay",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _colorScheme.primary,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.ellipsisVertical),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: _colorScheme.input),
            ),
            onSelected: (value) => Navigator.pushNamed(context, '/$value'),
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'settings',
                child: Text('Settings'),
              ),
              PopupMenuItem<String>(
                value: 'help',
                child: Text('Help'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ShadCard(
            padding: const EdgeInsets.all(16),
            border: Border(
              top: BorderSide.none,
              left: BorderSide(color: _colorScheme.border),
              bottom: BorderSide(color: _colorScheme.border),
              right: BorderSide(color: _colorScheme.border),
            ),
            radius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _onSelectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: _colorScheme.muted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  color: _colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('dd/MM/yyyy')
                                      .format(_selectedDate),
                                  style: TextStyle(
                                    color: _colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
                          style: TextStyle(
                            color: _colorScheme.mutedForeground,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    // Quick Date Navigation
                    Row(
                      children: [
                        _buildQuickDateButton(
                          'Yesterday',
                          DateTime.now().subtract(const Duration(days: 1)),
                        ),
                        const SizedBox(width: 4),
                        _buildQuickDateButton('Today', DateTime.now()),
                        const SizedBox(width: 4),
                        _buildQuickDateButton(
                          'Tomorrow',
                          DateTime.now().add(const Duration(days: 1)),
                        )
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Stats Row
                Row(
                  children: [
                    _buildStatCard(
                      'Total',
                      _stats['total']?.toString() ?? '0',
                      LucideIcons.list,
                      Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'Done',
                      _stats['completed']?.toString() ?? '0',
                      LucideIcons.circleCheckBig,
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'High Priority',
                      _stats['high_priority']?.toString() ?? '0',
                      LucideIcons.info,
                      Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _getData,
                    color: _colorScheme.accentForeground,
                    backgroundColor: _colorScheme.accent,
                    child: _activities.isEmpty
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: _buildEmptyState(),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _activities.length,
                            separatorBuilder: (c, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final activity = _activities[index];
                              return ActivityCard(
                                activity: activity,
                                onTap: () => _onEdit(activity),
                                onToggleComplete: () =>
                                    _toggleCompletion(activity),
                                onDelete: () => _onDelete(activity),
                                isReadOnly: isPast,
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: ShadButton(
        onPressed: _onCreate,
        decoration: const ShadDecoration(shape: BoxShape.circle),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildQuickDateButton(String label, DateTime date) {
    final isSelected = Utils.isSameDay(date, _selectedDate);
    return GestureDetector(
      onTap: () {
        setState(() => _selectedDate = date);
        _getData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _colorScheme.primary : _colorScheme.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isSelected
                ? _colorScheme.primaryForeground
                : _colorScheme.accentForeground,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: ShadCard(
        rowMainAxisAlignment: MainAxisAlignment.center,
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: _colorScheme.primary, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: _colorScheme.mutedForeground,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note,
            size: 64,
            color: _colorScheme.mutedForeground.withOpacity(0.8),
          ),
          const SizedBox(height: 16),
          Text(
            'There are no activities yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: _colorScheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first activity',
            style: TextStyle(
              fontSize: 14,
              color: _colorScheme.mutedForeground.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
