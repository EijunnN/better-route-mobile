import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import '../router/router.dart';

/// Bridges OneSignal push events to the in-app router.
///
/// Initialized once at app startup. Holds a soft reference to the
/// active [GoRouter] (the router builds AFTER the app boots, so it
/// can't be wired at OneSignal.initialize time) and a flag tracking
/// whether the chat screen is currently in the foreground.
///
/// Two responsibilities:
///   1. **Click**: tapping a chat push opens the chat screen.
///   2. **Foreground**: if a chat push arrives while the chat screen
///      is already open, suppress the banner — the message is already
///      landing live over the WebSocket.
class PushRouter {
  static final PushRouter _i = PushRouter._();
  factory PushRouter() => _i;
  PushRouter._();

  GoRouter? _router;
  bool _chatVisible = false;
  bool _wired = false;
  String? _pendingChatNavigation;

  /// Called by the chat screen on init/dispose.
  void setChatVisible(bool visible) {
    _chatVisible = visible;
  }

  /// Wire OneSignal listeners. Safe to call multiple times — idempotent.
  /// Call from `main()` right after `OneSignal.initialize`.
  void wireOneSignal() {
    if (_wired) return;
    _wired = true;
    OneSignal.Notifications.addClickListener(_onClick);
    OneSignal.Notifications.addForegroundWillDisplayListener(_onForeground);
  }

  /// Called by the app once the router is built so we can drive
  /// navigation from push events. Drains any pending navigation that
  /// arrived before the router was ready (e.g. cold-start from a push).
  void attachRouter(GoRouter router) {
    _router = router;
    final pending = _pendingChatNavigation;
    if (pending != null) {
      _pendingChatNavigation = null;
      // Defer one frame so the router has finished its first build.
      Future.microtask(() {
        try {
          router.push(pending);
        } catch (e) {
          debugPrint('[push] deferred navigation failed: $e');
        }
      });
    }
  }

  void _onClick(OSNotificationClickEvent event) {
    final data = event.notification.additionalData;
    final type = data?['type'];
    if (type != 'chat') return;
    _goToChat();
  }

  void _onForeground(OSNotificationWillDisplayEvent event) {
    final data = event.notification.additionalData;
    final type = data?['type'];
    if (type == 'chat' && _chatVisible) {
      // Already on the chat screen — the message is arriving live, the
      // banner would be redundant noise.
      event.preventDefault();
    }
  }

  void _goToChat() {
    final router = _router;
    if (router == null) {
      // Cold start path: the router may not exist yet (OneSignal
      // delivers click events very early). Stash and replay once
      // the app finishes booting.
      _pendingChatNavigation = AppRoutes.chat;
      return;
    }
    try {
      router.push(AppRoutes.chat);
    } catch (e) {
      debugPrint('[push] router.push failed: $e');
    }
  }
}
