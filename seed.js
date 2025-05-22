const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});
const db = admin.firestore();

async function seed() {
  // 1) Users
  const usersRef = db.collection('users');
  const users = {
    userA: {
      email: 'alice@example.com',
      role: 'fan',
      createdAt: admin.firestore.Timestamp.now(),
      bandIds: []
    },
    userB: {
      email: 'bob@band.com',
      role: 'merchant',
      createdAt: admin.firestore.Timestamp.now(),
      bandIds: ['band1','band2']
    }
  };
  for (const [id, data] of Object.entries(users)) {
    await usersRef.doc(id).set(data);
  }

  // 2) Products
  const productsRef = db.collection('products');
  await productsRef.doc('prod1').set({
    band_id: 'band1',
    title: 'Tour Tee',
    price: 29.99,
    sizes: ['S','M','L'],
    inventory: { S: 100, M: 75, L: 50 },
    image_url: 'https://…/tee.jpg',
    active: true
  });

  // 3) Orders
  const ordersRef = db.collection('orders');
  await ordersRef.doc('order1').set({
    user_id: 'userA',
    band_id: 'band1',
    items: [
      { product_id: 'prod1', size: 'M', qty: 2 }
    ],
    amount: 59.98,
    status: 'pending_pickup',
    qr_code: 'QR_ABC123',
    created_at: admin.firestore.Timestamp.now()
  });

  // 4) Events
  const eventsRef = db.collection('events');
  await eventsRef.doc('event1').set({
    name: 'Rock Fest',
    venue_name: 'Big Arena',
    address: '123 Main St',
    start_date: admin.firestore.Timestamp.fromDate(new Date('2025-08-01T18:00:00')),
    end_date: admin.firestore.Timestamp.fromDate(new Date('2025-08-01T23:00:00')),
    latitude: 40.7128,
    longitude: -74.0060,
    geofence_radius: 200,  // meters
    active: true,
    merchant_ids: ['band1']
  });

  // 5) Bands
  const bandsRef = db.collection('bands');
  await bandsRef.doc('band1').set({
    name: 'The Rockers',
    description: 'An awesome rock band.',
    logo_url: 'https://…/logo.png',
    owner_user_id: 'userB',
    member_user_ids: ['userB']
  });

  console.log('Seeding complete!');
  process.exit(0);
}

seed().catch(err => {
  console.error(err);
  process.exit(1);
});
