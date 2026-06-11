importScripts("https://www.gstatic.com/firebasejs/8.6.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.6.1/firebase-messaging.js");


firebase.initializeApp({
    apiKey: "AIzaSyAawOvKsHwBHHc_FhoofahQUP3UHxPs-EU",
    authDomain: "lastlab-d3e87.firebaseapp.com",
    projectId: "lastlab-d3e87",
    storageBucket: "lastlab-d3e87.firebasestorage.app",
    messagingSenderId: "840925341590",
    appId: "1:840925341590:web:43075dac1be168f1a31fb7"
  // measurementId: "YOUR_MEASUREMENT_ID",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((m) => {
  console.log("onBackgroundMessage", m);
});
