const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Create a test member
const testMember = {
  clientCode: 'TEST001',
  fullName: 'Test Member',
  age: 25,
  sex: 'M',
  email: 'test@example.com',
  primaryPhone: '+1234567890',
  address: '123 Test Street',
  emergencyContact: '+1987654321',
  membershipStatus: 'active',
  joinDate: admin.firestore.Timestamp.now(),
  role: 'member',
  subscriptionEndDate: admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 30 * 24 * 60 * 60 * 1000) // 30 days from now
  )
};

// Add the member to Firestore
db.collection('members').doc(testMember.clientCode).set(testMember)
  .then(() => {
    console.log('Test member created successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('Error creating test member:', error);
    process.exit(1);
  });
