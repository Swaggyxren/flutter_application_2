import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NotifPermission {
  static const _ch = MethodChannel('ledsync/notif_listener');

  static Future<bool> isEnabled() async {
    try {
      final ok = await _ch.invokeMethod<bool>('isEnabled');
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettings() async {
    try {
      await _ch.invokeMethod('openSettings');
    } catch (_) {}
  }

  static Widget _blurDialog({required Widget child}) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: child,
          ),
        ),
      ),
    );
  }

  static Future<void> _waitUntilEnabled(BuildContext context) async {
    if (!context.mounted) return;

    // show loading (blurred) overlay
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "WaitingPermission",
      barrierColor: Colors.black.withAlpha(120),
      pageBuilder: (ctx, a1, a2) {
        return _blurDialog(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(245),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    "Waiting for Notification Access...\nEnable it, then come back.",
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    // poll until enabled
    Timer? timer;
    timer = Timer.periodic(const Duration(milliseconds: 450), (_) async {
      final ok = await isEnabled();
      if (ok) {
        timer?.cancel();
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop(); // close loading
      }
    });
  }

  /// Call this at startup (after first frame) + also on resume.
  static Future<void> ensureEnabled(BuildContext context) async {
    final ok = await isEnabled();
    if (ok || !context.mounted) return;

    // Ask dialog (blur background)
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "NotifPermission",
      barrierColor: Colors.black.withAlpha(120),
      pageBuilder: (ctx, a1, a2) {
        return _blurDialog(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(245),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Permission required",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "To sync LEDs with notifications, enable Notification Access for this app.",
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
                      child: const Text("Not now"),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(ctx, rootNavigator: true).pop();
                        await openSettings();
                        // show loading until enabled
                        await _waitUntilEnabled(context);
                      },
                      child: const Text("Open Settings"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
