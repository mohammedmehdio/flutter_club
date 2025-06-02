const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');
const readline = require('readline').createInterface({
  input: process.stdin,
  output: process.stdout
});

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

function generateClientCode(length = 6) {
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';
  for (let i = 0; i < length; i++) {
    result += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  return result;
}

async function getNextSequenceValue(sequenceName) {
  const sequenceRef = db.collection('sequences').doc(sequenceName);
  const sequenceDoc = await sequenceRef.get();

  if (!sequenceDoc.exists) {
    // If the sequence doesn't exist, start it at 1
    await sequenceRef.set({ currentValue: 1 });
    return 1;
  } else {
    // Atomically increment the current value
    const newCurrentValue = admin.firestore.FieldValue.increment(1);
    await sequenceRef.update({ currentValue: newCurrentValue });
    // Fetch the document again to get the updated value
    const updatedSequenceDoc = await sequenceRef.get();
    return updatedSequenceDoc.data().currentValue;
  }
}


async function promptForInput(question) {
  return new Promise((resolve) => {
    readline.question(question, (answer) => {
      resolve(answer.trim());
    });
  });
}

async function addNewMember() {
  try {
    const clientCodeNumber = await getNextSequenceValue('clientCode');
    const clientCode = `MEMBER${String(clientCodeNumber).padStart(4, '0')}`; // e.g., MEMBER0001
    console.log(`Generated Client Code: ${clientCode}`);

    const fullName = await promptForInput('Full Name: ');
    const ageString = await promptForInput('Age: ');
    const age = parseInt(ageString, 10);
    const sex = await promptForInput('Sex (M/F/Other): ');
    const email = await promptForInput('Email (for login & communication): ');
    const primaryPhone = await promptForInput('Primary Phone: ');
    const address = await promptForInput('Address: ');
    const emergencyContact = await promptForInput('Emergency Contact Phone: ');
    const dobString = await promptForInput('Date of Birth (YYYY-MM-DD): '); // New prompt
    const membershipStatus = await promptForInput('Membership Status (e.g., active, pending_activation) [default: active]: ') || 'active';
    const role = await promptForInput('Role (e.g., member, coach) [default: member]: ') || 'member';
    
    let subscriptionDays = await promptForInput('Subscription duration in days (e.g., 30, 365) [default: 30]: ');
    subscriptionDays = parseInt(subscriptionDays) || 30;

    const joinDate = admin.firestore.Timestamp.now();
    const subscriptionEndDate = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() + subscriptionDays * 24 * 60 * 60 * 1000)
    );
    const dateOfBirth = dobString ? admin.firestore.Timestamp.fromDate(new Date(dobString)) : null; // Convert to Timestamp or null

    // 1. Create Client Code Document with ALL member details
    const clientCodeDocData = {
      email: email,
      fullName: fullName,
      age: age,
      sex: sex,
      primaryPhone: primaryPhone,
      address: address,
      emergencyContact: emergencyContact,
      dateOfBirth: dateOfBirth,
      membershipStatus: membershipStatus,
      role: role,
      joinDate: joinDate, // Or use a placeholder if registrationDate is set by server timestamp in app
      subscriptionEndDate: subscriptionEndDate,
      isValid: true,
      isClaimed: false,
      // uid will be set in the members document by the app
    };
    await db.collection('clientCodes').doc(clientCode).set(clientCodeDocData);
    console.log(`Client code '${clientCode}' with member details created in 'clientCodes' collection.`); // Corrected template literal

    // 2. Member Document will be created by the app upon signup/claim
    // No longer creating members document here.
    // const memberData = { ... };
    // await db.collection('members').doc(clientCode).set(memberData);
    
    console.log(`\nMember can now sign up using Client Code: ${clientCode} and Email: ${email}`);
    console.log('The application will create the corresponding document in the "members" collection upon successful signup.');

  } catch (error) {
    console.error('Error adding new member:', error);
  } finally {
    readline.close();
  }
}

addNewMember();
