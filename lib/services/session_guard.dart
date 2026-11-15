import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import 'auth_service.dart';

/// Centralized, idempotent handler for HTTP 401 unauthorized responses.
class SessionGuard {
  SessionGuard._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static DateTime? _lastHandledAt;
  static bool _isHandling = false;
  static const Duration _cooldown = Duration(seconds: 3);

  /// Clears the stored auth token, navigates to [LoginScreen] clearing the
  /// back stack, and shows an informational SnackBar.
  ///
  /// Consecutive calls within the cooldown window are ignored so parallel
  /// failing requests only trigger one redirect and one SnackBar.
  static Future<void> handleUnauthorized({AuthService? authService}) async {
    final now = DateTime.now();
    if (_isHandling) return;
    if (_lastHandledAt != null &&
        now.difference(_lastHandledAt!) < _cooldown) {
      return;
    }

    _isHandling = true;
    _lastHandledAt = now;

    try {
      await (authService ?? AuthService()).clearToken();

      final navigator = navigatorKey.currentState;
      final context = navigatorKey.currentContext;

      if (navigator != null) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }

      if (context != null && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Sesi berakhir, silakan masuk lagi.'),
          ),
        );
      }
    } finally {
      _isHandling = false;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _lastHandledAt = null;
    _isHandling = false;
  }
}
