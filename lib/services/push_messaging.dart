import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app/repositories/user_repo.dart';
import "package:universal_html/html.dart" as html;

/// VAPID key for web push notifications.
/// FIXME: DO NOT hardcode the VAPID key in production. Store it securely in environment variables using, for example, the `flutter_dotenv` package
const String vapidKey = 'BPSnKADKT36wTKRKlr8IcgsmyCPd2IeIUR-JLnEDJQuFDmA0phQbFxwEHn777SBqwTS64JwO931CmR-8oFwMW5Q';

/// Annotated as entry point to prevent being tree-shaken in release mode.
@pragma('vm:entry-point')
Future<void> _backgroundMessageHandler(RemoteMessage message) async {
  debugPrint(
      "RemoteMessagingService: Received a data message in the background: ${message.data.toString()}");

  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  // await Firebase.initializeApp();
}

class PushMessagingService {
  final UserRepository _userRepository;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final subscribedTopics = <String>{};

  PushMessagingService({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository();

  /// Request permission for receiving push notifications and subscribe to the provided topics. Returns whether the user granted permission.
  Future<bool> initialize({
    required String userId,
    required List<String> topics,
  }) async {
    final settings = await _firebaseMessaging.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint(
          'Push notification permission not granted: ${settings.authorizationStatus}');
      // User denied permission
      return false;
    }

    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Register callbacks for incoming messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
          'RemoteMessagingService: Received a message in the foreground: ${message.data.toString()}');
      // Process the message here
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
          'RemoteMessagingService: Opened a notification message: ${message.data.toString()}');
      // Process the open event here
    });
    FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);

    // Register the service worker for web
    if (kIsWeb) {
      await html.window.navigator.serviceWorker
          ?.register('/firebase-messaging-sw.js');
    }

    // Get the device token and sync user doc
    String? token = await _getToken();
    if (token != null) {
      await _postUpdateToken(userId, token, topics);
    } else {
      debugPrint('Push messaging token is null; delete notifications disabled');
    }

    // Listen to token changes and sync user doc
    _firebaseMessaging.onTokenRefresh.listen((token) {
      _postUpdateToken(userId, token, topics);
    }).onError((err) {
      debugPrint('Error refreshing push messaging token: $err');
    });

    return true;
  }

  Future<String?> _getToken() async {
    String? token;
    if (kIsWeb) {
      token = await _firebaseMessaging.getToken(vapidKey: vapidKey);
    } else {
      token = await _firebaseMessaging.getToken();
    }
    debugPrint('Push messaging token: $token');
    return token;
  }

  Future<void> _postUpdateToken(
      String userId, String token, List<String> topics) async {
    // Save the token first so direct per-user notifications can target this user.
    await _userRepository.updateFcmToken(userId, token);

    // Subscribe to topics
    await _subscribeToTopics(token, topics);
  }

  Future<void> _subscribeToTopics(String token, List<String> topics) async {
    List<Future<String>> futures = [];
    for (String topic in topics) {
      if (!subscribedTopics.contains(topic)) {
        futures.add(() async {
          // Subscribe to a new topic
          if (kIsWeb) {
            final HttpsCallable callable = FirebaseFunctions.instance
                .httpsCallable('groupChatAppSubscribeToTopic');
            await callable.call(<String, dynamic>{
              'token': token,
              'topic': topic,
            });
          } else {
            await _firebaseMessaging.subscribeToTopic(topic);
          }
          return topic;
        }());
      }
    }
    // Await all futures in parallel
    final subscribed = await Future.wait(futures);
    subscribedTopics.addAll(subscribed);
  }

  Future<void> unsubscribeFromAllTopics() async {
    String? token = await _getToken();
    if (token == null) {
      return;
    }

    List<Future<void>> futures = [];
    for (String topic in subscribedTopics) {
      if (kIsWeb) {
        final HttpsCallable callable = FirebaseFunctions.instance
            .httpsCallable('groupChatAppUnsubscribeFromTopic');
        futures.add(callable.call(<String, dynamic>{
          'token': token,
          'topic': topic,
        }));
      } else {
        futures.add(_firebaseMessaging.unsubscribeFromTopic(topic));
      }
    }
    // Await all futures in parallel
    await Future.wait(futures);
    subscribedTopics.clear();
  }
}
