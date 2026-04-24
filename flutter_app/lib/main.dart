import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'core/di/injection.dart' as di;
import 'core/services/notification_scheduler.dart';
import 'features/reminders/data/datasources/reminder_local_datasource.dart';
import 'firebase_options.dart';

/// Top-level FCM background handler — must be a bare top-level function.
/// Called when the app is terminated or in the background and a data-only
/// FCM push arrives. Flutter_local_notifications handles the notification UI;
/// this handler just ensures Firebase is initialized before anything else runs.
@pragma('vm:entry-point')
Future<void> _fcmBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // No further processing needed: reminder & prayer notifications are
  // scheduled locally via flutter_local_notifications. This handler exists
  // to satisfy FCM's requirement for a registered background handler and to
  // allow future server-sent push payloads to be processed offline.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register FCM background handler before any other Firebase work
  FirebaseMessaging.onBackgroundMessage(_fcmBackgroundHandler);

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Initialize dependency injection
  await di.init();

  // Set preferred orientations (portrait only for elderly)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set up Bloc observer for debugging
  Bloc.observer = AppBlocObserver();

  // Re-register every persisted reminder at app launch so the OS alarm
  // table is refreshed. Covers reboots and aggressive OEM battery killers
  // (Xiaomi / Oppo / Huawei) that drop scheduled alarms. Fire-and-forget —
  // we don't block UI on this.
  _rescheduleRemindersOnStartup();

  runApp(const RafeeqApp());
}

Future<void> _rescheduleRemindersOnStartup() async {
  try {
    final local = GetIt.instance<ReminderLocalDatasource>();
    final scheduler = GetIt.instance<NotificationScheduler>();
    final reminders = await local.getReminders();
    await scheduler.rescheduleAll(reminders);
  } catch (_) {
    // Non-fatal — the next manual load of the Reminders page will retry.
  }
}

class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    debugPrint('${bloc.runtimeType} $change');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    debugPrint('${bloc.runtimeType} $error $stackTrace');
    super.onError(bloc, error, stackTrace);
  }
}
