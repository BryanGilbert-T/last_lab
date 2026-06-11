const { logger, https } = require("firebase-functions/v2");

const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");
const {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { user } = require("firebase-functions/v1/auth");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
});
const db = admin.firestore();

// Subscribe a client to a topic. This is useful for web clients that can't subscribe to topics directly. By default, callable functions have CORS configured to allow requests from all origins. You can follow this link: https://firebase.google.com/docs/functions/callable?gen=2nd#cors to configure your own CORS rules.
exports.groupChatAppSubscribeToTopic = https.onCall(async (request) => {
  const { token, topic } = request.data;
  const uid = request.auth.uid;

  if (!uid) {
    logger.error(
      "groupChatAppSubscribeToTopic: Error: Client must log in first."
    );
    throw new HttpsError("failed-precondition", "Please log in first.");
  }

  try {
    await admin.messaging().subscribeToTopic(token, topic);

    logger.debug(
      `groupChatAppSubscribeToTopic: Successfully subscribed device with token: ${token} to topic: ${topic}`
    );

    return { message: `Subscribed to ${topic}` };
  } catch (error) {
    logger.error(
      "groupChatAppSubscribeToTopic: Error processing HTTP request",
      error
    );
    throw new HttpsError("internal", "Internal server error.");
  }
});

exports.groupChatAppUnsubscribeFromTopic = https.onCall(async (request) => {
  const { token, topic } = request.data;
  const uid = request.auth.uid;

  if (!uid) {
    logger.error(
      "groupChatAppUnsubscribeFromTopic: Error: Client must log in first."
    );
    throw new HttpsError("failed-precondition", "Please log in first.");
  }

  try {
    await admin.messaging().unsubscribeFromTopic(token, topic);
    logger.debug(
      `groupChatAppUnsubscribeFromTopic:  Successfully unsubscribed device with token: ${token} from topic: ${topic}`
    );
    return { message: `Unsubscribed from ${topic}` };
  } catch (error) {
    logger.error(
      "groupChatAppUnsubscribeFromTopic: Error processing HTTP request",
      error
    );
    throw new HttpsError("internal", "Internal server error.");
  }
});

// Send push notifications when when a new chat message is created.
exports.groupChatAppPushMessage = onDocumentCreated(
  {
    document: "apps/group-chat/messages/{messageId}",
    region: "asia-east",
  },
  async (event) => {
    const messageId = event.params.messageId;
    // Utilizes the unique event ID provided by Firebase to ensure idempotency. This ID remains consistent across retries of the same event, preventing duplicate increments of the itemCount in case the function is invoked multiple times for the same creation event.
    const idempotencyRef = db.doc(
      `apps/group-chat/idempotencyKeys/${event.id}`
    );

    try {
      await db.runTransaction(async (transaction) => {
        // Skip processing if the event has already been processed
        const idempotencyDoc = await transaction.get(idempotencyRef);
        if (idempotencyDoc.exists) {
          logger.info(
            "groupChatAppPushMessage: Event already processed, skipping"
          );
          return;
        }

        // Send a push notification to the "chat" topic
        const snapshot = event.data;
        const response = await admin.messaging().send({
          notification: {
            title: snapshot.data()["userName"],
            body: snapshot.data()["text"],
          },
          // Optionally, send data payload to be handled by the client app itself
          data: {
            function: "groupChatAppPushMessage",
            messageId: messageId,
            text: snapshot.data()["text"],
            userId: snapshot.data()["userId"],
            userName: snapshot.data()["userName"],
          },
          topic: "chat",
        });

        // Marks this event as processed by setting an idempotency record. This record uses Firebase's server timestamp to indicate when the event was processed, providing a traceable log for debugging and audit purposes.
        transaction.set(idempotencyRef, {
          processedAt: FieldValue.serverTimestamp(),
        });
      });
      logger.debug("groupChatAppPushMessage: Event processed successfully");
    } catch (error) {
      logger.error("groupChatAppPushMessage: Error processing event", error);
    }
  }
);

// Set `isModerator` custom claim for the user if the `isModerator` doc field is set to true (in Firebase Console manually).
exports.groupChatAppSetModeratorCustomClaim = onDocumentUpdated(
  {
    document: "apps/group-chat/users/{userId}",
    region: "asia-east1",
  },
  async (event) => {
    const userId = event.params.userId;
    const userData = event.data.after.data();

    // No idempoency check needed here as the logic of this function is idempotent
    try {
      // The custom claim is available in the user's ID token only after the next sign-in
      await admin.auth().setCustomUserClaims(userId, {
        isModerator: userData["isModerator"],
      });
    } catch (error) {
      logger.error(
        "groupChatAppSetModeratorCustomClaim: Error setting custom claim",
        error
      );
    }

    logger.debug(
      "groupChatAppSetModeratorCustomClaim: Event processed successfully"
    );
  }
);

exports.groupChatAppNotifyMessageDeleted = onDocumentDeleted(
  {
    document: "apps/group-chat/messages/{messageId}",
    region: "asia-east",
  },
  async (event) => {
    const messageId = event.params.messageId;
    const idempotencyRef = db.doc(
      `apps/group-chat/idempotencyKeys/${event.id}`
    );

    try {
      await db.runTransaction(async (transaction) => {
        const idempotencyDoc = await transaction.get(idempotencyRef);
        if (idempotencyDoc.exists) {
          logger.info(
            "groupChatAppNotifyMessageDeleted: Event already processed, skipping"
          );
          return;
        }

        const deletedMessage = event.data.data();
        const authorId = deletedMessage["userId"];

        const authorRef = db.doc(`apps/group-chat/users/${authorId}`);
        const authorDoc = await transaction.get(authorRef);
        const token = authorDoc.exists ? authorDoc.data()["fcmToken"] : null;

        if (token) {
          await admin.messaging().send({
            notification: {
              title: "Your message was removed",
              body: `A moderator removed your message: "${deletedMessage["text"]}"`,
            },
            data: {
              function: "groupChatAppNotifyMessageDeleted",
              messageId: messageId,
              text: deletedMessage["text"] ?? "",
            },
            token: token,
          });
        } else {
          logger.info(
            "groupChatAppNotifyMessageDeleted: No device token for author, skipping notification"
          );
        }

        transaction.set(idempotencyRef, {
          processedAt: FieldValue.serverTimestamp(),
        });
      });
      logger.debug(
        "groupChatAppNotifyMessageDeleted: Event processed successfully"
      );
    } catch (error) {
      logger.error(
        "groupChatAppNotifyMessageDeleted: Error processing event",
        error
      );
    }
  }
);
