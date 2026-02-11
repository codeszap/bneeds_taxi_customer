importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.1/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyCA_27gawRghDSyN5rgSUTFeJaCKzJoOHQ",
  authDomain: "bneeds-taxi-customer-d009e.firebaseapp.com",
  projectId: "bneeds-taxi-customer-d009e",
  storageBucket: "bneeds-taxi-customer-d009e.firebasestorage.app",
  messagingSenderId: "948016817124",
  appId: "1:948016817124:web:61d21c18ec5c40540a5df1",
  measurementId: "G-WM530SSC62"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log("Received background message ", payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/icon-192.png",
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
