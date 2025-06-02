const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json'); // Ensure this path is correct
const readline = require('readline').createInterface({
  input: process.stdin,
  output: process.stdout
});

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function promptForInput(question, defaultValue = null) {
  return new Promise((resolve) => {
    readline.question(question, (answer) => {
      resolve(answer.trim() || defaultValue);
    });
  });
}

async function getNextSequenceValue(sequenceName) {
  const sequenceRef = db.collection('sequences').doc(sequenceName);
  const sequenceDoc = await sequenceRef.get();

  if (!sequenceDoc.exists) {
    await sequenceRef.set({ currentValue: 1 });
    return 1;
  } else {
    const newCurrentValue = admin.firestore.FieldValue.increment(1);
    await sequenceRef.update({ currentValue: newCurrentValue });
    const updatedSequenceDoc = await sequenceRef.get();
    return updatedSequenceDoc.data().currentValue;
  }
}

async function addNewCourse() {
  try {
    console.log('--- Adding New Course ---');

    const courseIdNumber = await getNextSequenceValue('courseId');
    const courseId = `COURSE${String(courseIdNumber).padStart(4, '0')}`; // e.g., COURSE0001
    console.log(`Generated Course ID: ${courseId}`);

    const name = await promptForInput('Course Name (e.g., Morning Yoga): ');
    const description = await promptForInput('Course Description: ');
    const coachName = await promptForInput('Coach Name: ');
    
    const scheduleDay = await promptForInput('Schedule Day (e.g., Monday, Wednesday, Friday): ');
    const scheduleTime = await promptForInput('Schedule Time (e.g., 09:00 AM): ');
    
    const durationMinutesStr = await promptForInput('Duration in minutes (e.g., 60): ', '60');
    const durationMinutes = parseInt(durationMinutesStr, 10);

    const maxCapacityStr = await promptForInput('Max Capacity (e.g., 15): ', '15');
    const maxCapacity = parseInt(maxCapacityStr, 10);

    const priceStr = await promptForInput('Price (e.g., 100.00): ', '0.00');
    const price = parseFloat(priceStr);

    const startDateStr = await promptForInput('Start Date (YYYY-MM-DD): ');
    const endDateStr = await promptForInput('End Date (YYYY-MM-DD, optional, can be same as start for one-off): ');

    const tagsStr = await promptForInput('Tags (comma-separated, e.g., yoga,beginner,wellness): ');
    const tags = tagsStr ? tagsStr.split(',').map(tag => tag.trim()) : [];

    const courseData = {
      id: courseId, // Storing the auto-generated ID also as a field
      name: name,
      description: description,
      coachName: coachName,
      schedule: { // Simple schedule, can be expanded
        days: scheduleDay.split(',').map(d => d.trim()), // Allows multiple days
        time: scheduleTime,
      },
      durationMinutes: durationMinutes,
      maxCapacity: maxCapacity,
      enrolledUids: [], // Initially no one is enrolled
      price: price,
      startDate: startDateStr ? admin.firestore.Timestamp.fromDate(new Date(startDateStr)) : null,
      endDate: endDateStr ? admin.firestore.Timestamp.fromDate(new Date(endDateStr)) : null,
      tags: tags,
      isActive: true, // Default to active
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('courses').doc(courseId).set(courseData);
    console.log(`
Successfully added course '${name}' with ID '${courseId}' to Firestore.`);
    console.log('You may need to restart or refresh the app to see the new course.');

  } catch (error) {
    console.error('Error adding new course:', error);
  } finally {
    readline.close();
  }
}

addNewCourse();
