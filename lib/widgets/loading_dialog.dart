import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LoadingDialog {
  static void show(BuildContext context, {String title = 'Loading'}) {
    var theme = ShadTheme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        return PopScope(
          canPop: false, // Disable back button
          child: Center(
            // Center the dialog
            child: Container(
              constraints: const BoxConstraints(minWidth: 100, maxWidth: 250),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.colorScheme.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Take up minimal space
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: theme.textTheme.muted,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Function to hide the loading dialog
  static void hide(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop(); // Close the dialog
    }
  }
}
