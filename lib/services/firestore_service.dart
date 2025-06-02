import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member.dart';
import '../models/course.dart'; // Added import for Course model

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String membersCollection = 'members';
  final String clientCodesCollection = 'clientCodes';

  // Get member by client code
  Future<Member?> getMemberByClientCode(String clientCode) async {
    try {
      print(
          '[FirestoreService] Attempting to get member by clientCode (docId): $clientCode'); // DEBUG
      // clientCode is the document ID for the members collection
      final DocumentSnapshot memberDoc =
          await _firestore.collection(membersCollection).doc(clientCode).get();

      if (memberDoc.exists) {
        print(
            '[FirestoreService] Member found for clientCode (docId): $clientCode'); // DEBUG
        return Member.fromFirestore(memberDoc);
      } else {
        print(
            '[FirestoreService] No member found for clientCode (docId): $clientCode'); // DEBUG
        return null;
      }
    } catch (e) {
      print(
          '[FirestoreService] Error fetching member by clientCode (docId) $clientCode: $e'); // DEBUG
      rethrow; // Rethrow to be handled by caller
    }
  }

  // Update last login
  Future<void> updateLastLogin(String clientCode) async {
    try {
      final memberDocRef =
          _firestore.collection(membersCollection).doc(clientCode);
      // Security rules will ensure only the owner can update.
      await memberDocRef.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
      print('Last login updated for $clientCode');
    } catch (e) {
      print('Error updating last login for $clientCode: $e');
      // Non-critical, so don't rethrow unless necessary for flow
    }
  }

  // Update member data
  Future<void> updateMember(
      String clientCode, Map<String, dynamic> data) async {
    try {
      // Security rules will ensure only the owner can update.
      await _firestore
          .collection(membersCollection)
          .doc(clientCode)
          .update(data);
      print('Member $clientCode updated.');
    } catch (e) {
      print('Error updating member $clientCode: $e');
      rethrow; // Rethrow as this is likely a direct user action
    }
  }

  // Check if client code is valid and available for signup
  Future<Map<String, dynamic>?> getClientCodeDataIfAvailable(
      String clientCode) async {
    print(
        '[FirestoreService] Attempting getClientCodeDataIfAvailable for clientCode: $clientCode'); // DEBUG
    try {
      final docSnapshot = await _firestore
          .collection(clientCodesCollection)
          .doc(clientCode)
          .get();
      print(
          '[FirestoreService] Fetched clientCode doc snapshot. Exists: ${docSnapshot.exists}'); // DEBUG
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        print('[FirestoreService] Client code data: $data'); // DEBUG
        if (data['isValid'] == true &&
            (data['isClaimed'] == null || data['isClaimed'] == false)) {
          print(
              '[FirestoreService] Client code $clientCode is valid and available.'); // DEBUG
          return data; // Return the client code data if available
        }
        print(
            '[FirestoreService] Client code $clientCode is NOT valid or already claimed.'); // DEBUG
      }
      return null; // Not found, not valid, or already claimed
    } catch (e) {
      print(
          '[FirestoreService] Error in getClientCodeDataIfAvailable for $clientCode: $e'); // DEBUG
      return null;
    }
  }

  // Create member document in 'members' collection and claim the client code in 'clientCodes'
  Future<void> createMemberAndClaimClientCode(String clientCode, String userId,
      Map<String, dynamic> clientCodeData) async {
    print(
        '[FirestoreService] Attempting createMemberAndClaimClientCode for clientCode: $clientCode, userId: $userId'); // DEBUG
    print(
        '[FirestoreService] Initial clientCodeData for member creation: $clientCodeData'); // DEBUG

    final DocumentReference memberDocRef =
        _firestore.collection('members').doc(clientCode);
    final DocumentReference clientCodeDocRef =
        _firestore.collection('clientCodes').doc(clientCode);

    // Prepare data for the new member document
    // Ensure all required fields for Member.fromFirestore are present
    Map<String, dynamic> memberDataForTransaction = {
      'uid': userId, // This is crucial and comes from Auth user
      'clientCode': clientCode,
      'fullName': clientCodeData['fullName'] ?? 'N/A',
      'email': clientCodeData['email'] ?? '$clientCode@yourclub.com',
      'primaryPhone': clientCodeData['primaryPhone'] ?? 'N/A',
      'address': clientCodeData['address'] ?? 'N/A',
      'emergencyContact': clientCodeData['emergencyContact'] ?? 'N/A',

      // Handle Timestamps carefully
      'dateOfBirth': clientCodeData.containsKey('dateOfBirth') &&
              clientCodeData['dateOfBirth'] is Timestamp
          ? clientCodeData['dateOfBirth']
          : Timestamp.fromDate(
              DateTime(1900, 1, 1)), // Placeholder if missing or wrong type

      'registrationDate': clientCodeData.containsKey('joinDate') &&
              clientCodeData['joinDate'] is Timestamp
          ? clientCodeData['joinDate']
          : FieldValue
              .serverTimestamp(), // Use joinDate if available, else server timestamp

      'subscriptionEndDate':
          clientCodeData.containsKey('subscriptionEndDate') &&
                  clientCodeData['subscriptionEndDate'] is Timestamp
              ? clientCodeData['subscriptionEndDate']
              : Timestamp.fromDate(DateTime.now()
                  .add(const Duration(days: 30))), // Default if missing

      'membershipStatus': clientCodeData['membershipStatus'] ?? 'active',
      'role': clientCodeData['role'] ?? 'member',

      // Optional fields from clientCodeData, ensure they are handled if not present
      'gender': clientCodeData['gender'],
      'profilePhotoUrl': clientCodeData['profilePhotoUrl'],
      'enrolledCourseIds': clientCodeData['enrolledCourseIds'] ?? [],
      'paymentHistory': clientCodeData['paymentHistory'] ?? {},
      'medicalConditions': clientCodeData['medicalConditions'],
      'notes': clientCodeData['notes'],
      // Fields that should not be in memberData or are set by server/defaults
      // 'isClaimed', 'isValid', 'claimedAt', 'claimedBy' are for clientCodes collection
    };

    // Remove fields that are specific to clientCodes collection or not needed in members
    // This step is more of a safeguard if clientCodeData had extra fields not intended for Member model
    // However, the explicit mapping above is generally safer.
    // memberDataForTransaction.remove('isClaimed');
    // memberDataForTransaction.remove('isValid');
    // memberDataForTransaction.remove('claimedAt');
    // memberDataForTransaction.remove('claimedBy');
    // memberDataForTransaction.remove('joinDate'); // Already mapped to registrationDate

    print(
        '[FirestoreService] Data prepared for memberDocRef.set in transaction: $memberDataForTransaction'); // DEBUG

    // Use a transaction to ensure atomicity
    return _firestore.runTransaction((transaction) async {
      print(
          '[FirestoreService] Starting Firestore transaction for $clientCode.'); // DEBUG

      // It's crucial that memberDataForTransaction contains all non-nullable fields
      // required by your Firestore security rules if they check request.resource.data
      // For a simple 'allow create: if true;', this is less of an issue, but good practice.
      transaction.set(memberDocRef, memberDataForTransaction);
      print(
          '[FirestoreService] Transaction: memberDocRef.set called for $clientCode.'); // DEBUG

      transaction.update(clientCodeDocRef, {
        'isClaimed': true,
        'claimedAt': FieldValue.serverTimestamp(),
        'claimedBy': userId
      });
      print(
          '[FirestoreService] Transaction: clientCodeDocRef.update called for $clientCode.'); // DEBUG
      print(
          '[FirestoreService] Firestore transaction for $clientCode completed operations within callback.'); // DEBUG
    }).then((_) {
      print(
          '[FirestoreService] Firestore transaction for $clientCode committed successfully.'); // DEBUG
    }).catchError((error) {
      print(
          '[FirestoreService] Error IN Firestore transaction for $clientCode (createMemberAndClaimClientCode): $error'); // DEBUG
      throw error; // Rethrow the error to be caught by the caller
    });
  }

  Future<String?> getEmailByClientCode(String clientCode) async {
    try {
      print(
          '[FirestoreService] Attempting to get email for clientCode: $clientCode'); // DEBUG
      final docSnapshot = await _firestore
          .collection(clientCodesCollection)
          .doc(clientCode)
          .get();
      if (docSnapshot.exists && docSnapshot.data()!.containsKey('email')) {
        print(
            '[FirestoreService] Email found for clientCode $clientCode: ${docSnapshot.data()!['email']}'); // DEBUG
        return docSnapshot.data()!['email'] as String?;
      }
      print(
          '[FirestoreService] Email not found for clientCode $clientCode'); // DEBUG
      return null;
    } catch (e) {
      print(
          '[FirestoreService] Error fetching email for clientCode $clientCode: $e'); // DEBUG
      return null;
    }
  }

  // Fetch all courses
  Future<List<Course>> getCourses() async {
    try {
      print('[FirestoreService] Attempting to fetch all courses.'); // DEBUG
      final QuerySnapshot courseSnapshot =
          await _firestore.collection('courses').get();

      if (courseSnapshot.docs.isNotEmpty) {
        final courses = courseSnapshot.docs
            .map((doc) => Course.fromFirestore(doc))
            .toList();
        print('[FirestoreService] Fetched ${courses.length} courses.'); // DEBUG
        return courses;
      } else {
        print('[FirestoreService] No courses found.'); // DEBUG
        return [];
      }
    } catch (e) {
      print('[FirestoreService] Error fetching courses: $e'); // DEBUG
      rethrow;
    }
  }

  // Enroll member in a course
  Future<void> enrollMemberInCourse(
      String memberClientCode, String courseId, String memberUid) async {
    print(
        '[FirestoreService] Attempting to enroll member $memberClientCode (UID: $memberUid) in course $courseId');
    final memberDocRef =
        _firestore.collection(membersCollection).doc(memberClientCode);
    final courseDocRef = _firestore.collection('courses').doc(courseId);

    try {
      await _firestore.runTransaction((transaction) async {
        // Get the current course document
        final courseSnapshot = await transaction.get(courseDocRef);
        if (!courseSnapshot.exists) {
          throw Exception("Course $courseId not found.");
        }
        final courseData =
            courseSnapshot.data()! as Map<String, dynamic>; // Cast to Map
        List<String> enrolledUids =
            List<String>.from(courseData['enrolledUids'] ?? []);
        int maxCapacity = courseData['maxCapacity'] ?? 0;

        // Check if course is full
        if (enrolledUids.length >= maxCapacity) {
          throw Exception("Course $courseId is full.");
        }

        // Check if member is already enrolled
        if (enrolledUids.contains(memberUid)) {
          // Already enrolled, maybe just log or silently succeed
          print(
              '[FirestoreService] Member $memberUid already enrolled in course $courseId.');
          return;
        }
        if ((courseData['isActive'] ?? true) == false) {
          throw Exception("Course $courseId is not active.");
        }

        // Update course document: add member's UID to enrolledUids
        transaction.update(courseDocRef, {
          'enrolledUids': FieldValue.arrayUnion([memberUid])
        });

        // Update member document: add courseId to member's enrolledCourseIds
        transaction.update(memberDocRef, {
          'enrolledCourseIds': FieldValue.arrayUnion([courseId])
        });
        print(
            '[FirestoreService] Transaction successful for enrolling $memberUid in $courseId.');
      });
    } catch (e) {
      print(
          '[FirestoreService] Error enrolling member $memberClientCode in course $courseId: $e');
      rethrow;
    }
  }

  // TODO: Implement unenrollMemberFromCourse if needed
}
