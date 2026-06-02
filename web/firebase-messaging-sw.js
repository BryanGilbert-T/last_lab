importScripts("https://www.gstatic.com/firebasejs/8.6.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.6.1/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "YOUR_API_KEY",
  appId: "YOUR_APP_ID",
  messagingSenderId: "YUR_MESSAGING_SENDER_ID",
  projectId: "YOUR_PROJECT_ID",
  authDomain: "YOUR_AUTH_DOMAIN",
  storageBucket: "YOUR_STORAGE_BUCKET",
  // measurementId: "YOUR_MEASUREMENT_ID",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((m) => {
  console.log("onBackgroundMessage", m);
});
