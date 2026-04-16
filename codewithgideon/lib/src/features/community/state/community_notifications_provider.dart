import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../cohorts/models/cohort_message_model.dart';
import '../../home/state/dashboard_provider.dart';
import '../../../core/services/notification_service.dart';

const String readNotificationIdsKey = 'community.readNotificationIds';
const String hiddenNotificationIdsKey = 'community.hiddenNotificationIds';

Future<Set<String>> loadReadNotificationIds() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(readNotificationIdsKey)?.toSet() ?? <String>{};
}

Future<Set<String>> loadHiddenNotificationIds() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(hiddenNotificationIdsKey)?.toSet() ?? <String>{};
}

Future<void> markNotificationRead(CohortMessageModel message) async {
  final prefs = await SharedPreferences.getInstance();
  final readIds = prefs.getStringList(readNotificationIdsKey)?.toSet() ?? <String>{};
  readIds.add(message.id);
  await prefs.setStringList(readNotificationIdsKey, readIds.toList());
}

Future<void> markNotificationsRead(Iterable<CohortMessageModel> messages) async {
  final prefs = await SharedPreferences.getInstance();
  final readIds = prefs.getStringList(readNotificationIdsKey)?.toSet() ?? <String>{};
  for (final message in messages) {
    readIds.add(message.id);
  }
  await prefs.setStringList(readNotificationIdsKey, readIds.toList());
}

Future<void> clearNotifications(Iterable<CohortMessageModel> messages) async {
  final prefs = await SharedPreferences.getInstance();
  final hiddenIds =
      prefs.getStringList(hiddenNotificationIdsKey)?.toSet() ?? <String>{};
  final readIds = prefs.getStringList(readNotificationIdsKey)?.toSet() ?? <String>{};
  for (final message in messages) {
    hiddenIds.add(message.id);
    readIds.add(message.id);
  }
  await prefs.setStringList(hiddenNotificationIdsKey, hiddenIds.toList());
  await prefs.setStringList(readNotificationIdsKey, readIds.toList());
}

final cohortMessagesProvider =
    StreamProvider.autoDispose<List<CohortMessageModel>>((ref) async* {
      final dashboard = await ref.watch(dashboardSnapshotProvider.future);
      final cohortKey = dashboard.activeCohort.cohortKey.trim();
      if (cohortKey.isEmpty) {
        yield <CohortMessageModel>[];
        return;
      }

      yield* ref.watch(cohortRepositoryProvider).watchMessagesForCohort(cohortKey);
    });

final unreadMessagesCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
      final prefs = await SharedPreferences.getInstance();
      final messages = ref.watch(
        cohortMessagesProvider,
      ).maybeWhen(data: (items) => items, orElse: () => <CohortMessageModel>[]);
      final hiddenIds =
          prefs.getStringList(hiddenNotificationIdsKey)?.toSet() ?? <String>{};
      final readIds =
          prefs.getStringList(readNotificationIdsKey)?.toSet() ?? <String>{};
      final visibleMessages = messages
          .where((msg) => !hiddenIds.contains(msg.id))
          .toList();

      final lastRead = prefs.getInt('lastReadMessages') ?? 0;
      final unreadMessages = visibleMessages
          .where(
            (msg) =>
                !readIds.contains(msg.id) &&
                msg.createdAt.isAfter(DateTime.fromMillisecondsSinceEpoch(lastRead)),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final unreadCount = unreadMessages.length;

      if (unreadMessages.isNotEmpty) {
        final latestUnreadAt =
            unreadMessages.first.createdAt.millisecondsSinceEpoch;
        final lastNotified = prefs.getInt('lastNotifiedMessages') ?? 0;

        if (latestUnreadAt > lastNotified) {
          await NotificationService().showNewMessageNotification(
            payload: '/community/messages',
          );
          await prefs.setInt('lastNotifiedMessages', latestUnreadAt);
        }
      }

      return unreadCount;
    });
