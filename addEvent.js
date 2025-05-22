// scripts/addEvent.js
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');  // adjust path if needed

// initialize the Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

async function addTestEvent() {
  const eventData = {
    name: "Test Concert Event",
    venue_name: "Test Venue",
    address: "123 Test St, New York, NY",
    start_date: admin.firestore.Timestamp.fromDate(new Date("2025-05-21T19:00:00")),
    end_date:   admin.firestore.Timestamp.fromDate(new Date("2025-05-21T23:00:00")),
    latitude: 40.7128,
    longitude: -74.0060,
    geofence_radius: 500,
    active: true,
    merchant_ids: ["mock_band_id"]
  };

  // use a custom ID or let Firestore auto-generate
  const docRef = db.collection("events").doc("testEvent1");
  await docRef.set(eventData);
  console.log("✅ Test event written to:", docRef.path);
}

addTestEvent().catch(console.error);
