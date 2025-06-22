import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ListSheetWidget<T> extends StatefulWidget {
  final T selected;
  final List<T> values;
  final List<GlobalKey> tileKeys;
  final void Function(T)? onChanged;
  final String? title;
  final Widget? Function(T, bool)? trailing;

  const ListSheetWidget({
    super.key,
    required this.selected,
    required this.values,
    required this.tileKeys,
    this.title,
    this.trailing,
    this.onChanged,
  });

  @override
  State<ListSheetWidget<T>> createState() => _ListSheetWidgetState<T>();
}

class _ListSheetWidgetState<T> extends State<ListSheetWidget<T>> {
  late T _tempSelected;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tempSelected = widget.selected;
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSelected());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: colorScheme.input, width: 2)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.9,
          minHeight: screenHeight * 0.3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed Header
            if (widget.title != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.background,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.border,
                      width: 1,
                    ),
                  ),
                ),
                child: Text(
                  widget.title!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.foreground,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Scrollable Content
            Flexible(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: widget.values.length > 10,
                child: ListView.builder(
                  controller: _scrollController,
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: widget.values.length,
                  itemBuilder: (context, index) {
                    final value = widget.values[index];
                    final isSelected = value == _tempSelected;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isSelected
                            ? colorScheme.accent.withOpacity(0.1)
                            : null,
                      ),
                      child: ListTile(
                        key: widget.tileKeys[index],
                        title: Text(
                          value.toString(),
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedTileColor: colorScheme.accent,
                        trailing: widget.trailing != null
                            ? widget.trailing!(value, isSelected)
                            : null,
                        onTap: () => setState(() => _tempSelected = value),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Fixed Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.border,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ShadButton.outline(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ShadButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onChanged?.call(_tempSelected);
                      },
                      child: const Text("OK"),
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

  void _scrollToSelected() {
    final selectedIndex = widget.values.indexOf(_tempSelected);
    if (selectedIndex == -1) return;

    // Calculate the position to scroll to
    const itemHeight = 56.0; // Approximate ListTile height
    const padding = 8.0;
    final targetOffset = (selectedIndex * itemHeight) - padding;

    // Get the available scroll area height
    const footerHeight = 80.0;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxScrollHeight = screenHeight * 0.9;
    final headerHeight = widget.title != null ? 60.0 : 0.0;
    final availableHeight = maxScrollHeight - headerHeight - footerHeight;

    // Center the selected item if possible
    final centeredOffset =
        targetOffset - (availableHeight / 2) + (itemHeight / 2);

    // Ensure we don't scroll beyond bounds
    final maxScrollExtent =
        (widget.values.length * itemHeight) - availableHeight;
    final finalOffset =
        centeredOffset.clamp(0.0, maxScrollExtent.clamp(0.0, double.infinity));

    // Animate to the calculated position
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          finalOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
