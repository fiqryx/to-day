import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ExitInterceptor extends StatefulWidget {
  final Widget children;
  const ExitInterceptor({
    super.key,
    required this.children,
  });

  @override
  State<ExitInterceptor> createState() => _ExitInterceptorState();
}

class _ExitInterceptorState extends State<ExitInterceptor> {
  DateTime? lastBackPressTime;

  @override
  void initState() {
    super.initState();
    BackButtonInterceptor.add(_interceptor,
        name: "exit_interceptor", context: context);
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_interceptor);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.children;

  bool _interceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    if (stopDefaultButtonEvent) return false;

    // If a dialog (or any other route) is open, don't run the interceptor.
    if (info.ifRouteChanged(context)) return false;

    final now = DateTime.now();
    if (lastBackPressTime == null ||
        now.difference(lastBackPressTime!) > const Duration(seconds: 2)) {
      setState(() => lastBackPressTime = now);

      if (mounted) {
        Fluttertoast.showToast(
          msg: "Press back again to exit",
          toastLength: Toast.LENGTH_SHORT,
        );
      }

      return true;
    }

    return false;
  }
}
