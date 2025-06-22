import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final List<bool> _expandedStates = List.generate(5, (_) => false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ...List.generate(5, (index) => _buildFAQItem(index)),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(LucideIcons.mail),
              label: const Text('Contact Support'),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem(int index) {
    final questions = [
      'How to create a new activity?',
      'How to change notification settings?',
      'Can I sync across devices?',
      'How to export my data?',
      'Troubleshooting notifications'
    ];

    return Card(
      child: ExpansionTile(
        title: Text(questions[index]),
        trailing: Icon(
          _expandedStates[index]
              ? LucideIcons.chevronUp
              : LucideIcons.chevronDown,
        ),
        onExpansionChanged: (expanded) {
          setState(() => _expandedStates[index] = expanded);
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Detailed answer for: ${questions[index]}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
