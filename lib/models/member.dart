import 'package:cloud_firestore/cloud_firestore.dart';

class Member {
  final String id; // Document ID from Firestore
  final String uid; // Firebase Auth User ID
  final String clientCode;
  final String fullName;
  final String email;
  final String primaryPhone;
  final String address;
  final String emergencyContact;
  final DateTime? dateOfBirth; // Made nullable
  final DateTime registrationDate;
  final DateTime subscriptionEndDate;
  final String membershipStatus; // e.g., active, expired, frozen
  final String? gender;
  final String? profilePhotoUrl;
  final List<String>? enrolledCourseIds; // List of course IDs
  final Map<String, dynamic>? paymentHistory; // Could be more structured
  final String? medicalConditions; // Optional
  final String? notes; // Optional admin notes

  Member({
    required this.id,
    required this.uid,
    required this.clientCode,
    required this.fullName,
    required this.email,
    required this.primaryPhone,
    required this.address,
    required this.emergencyContact,
    this.dateOfBirth, // No longer required, can be null
    required this.registrationDate,
    required this.subscriptionEndDate,
    this.membershipStatus = 'active',
    this.gender,
    this.profilePhotoUrl,
    this.enrolledCourseIds,
    this.paymentHistory,
    this.medicalConditions,
    this.notes,
  });

  // Factory constructor to create a Member instance from a Firestore document
  factory Member.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Member(
      id: doc.id,
      uid: data['uid'] ?? '',
      clientCode: data['clientCode'] ?? '',
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      primaryPhone: data['primaryPhone'] ?? '',
      address: data['address'] ?? '',
      emergencyContact: data['emergencyContact'] ?? '',
      dateOfBirth:
          data.containsKey('dateOfBirth') && data['dateOfBirth'] != null
              ? (data['dateOfBirth'] as Timestamp).toDate()
              : null,
      registrationDate: (() {
        Timestamp? ts = data['registrationDate'] as Timestamp? ??
            data['joinDate'] as Timestamp?;
        if (ts == null) {
          // If critical, throw an error. For now, let's use a default or handle missing data upstream.
          // Consider logging this missing field.
          print(
              "Warning: registrationDate or joinDate is missing for member ${doc.id}. Using epoch as fallback.");
          return DateTime.fromMillisecondsSinceEpoch(
              0); // Fallback, consider if this is appropriate
        }
        return ts.toDate();
      })(),
      subscriptionEndDate: (() {
        Timestamp? ts = data['subscriptionEndDate'] as Timestamp?;
        if (ts == null) {
          // If critical, throw an error.
          print(
              "Warning: subscriptionEndDate is missing for member ${doc.id}. Using epoch as fallback.");
          return DateTime.fromMillisecondsSinceEpoch(0); // Fallback
        }
        return ts.toDate();
      })(),
      membershipStatus: data['membershipStatus'] ?? 'active',
      gender: data['gender'],
      profilePhotoUrl: data['profilePhotoUrl'],
      enrolledCourseIds: List<String>.from(data['enrolledCourseIds'] ?? []),
      paymentHistory: Map<String, dynamic>.from(data['paymentHistory'] ?? {}),
      medicalConditions: data['medicalConditions'],
      notes: data['notes'],
    );
  }

  // Method to convert a Member instance to a Firestore-compatible map
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'clientCode': clientCode,
      'fullName': fullName,
      'email': email,
      'primaryPhone': primaryPhone,
      'address': address,
      'emergencyContact': emergencyContact,
      if (dateOfBirth != null)
        'dateOfBirth': Timestamp.fromDate(dateOfBirth!), // Handle nullable
      'registrationDate': Timestamp.fromDate(registrationDate),
      'subscriptionEndDate': Timestamp.fromDate(subscriptionEndDate),
      'membershipStatus': membershipStatus,
      if (gender != null) 'gender': gender,
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      if (enrolledCourseIds != null) 'enrolledCourseIds': enrolledCourseIds,
      if (paymentHistory != null) 'paymentHistory': paymentHistory,
      if (medicalConditions != null) 'medicalConditions': medicalConditions,
      if (notes != null) 'notes': notes,
    };
  }
}
