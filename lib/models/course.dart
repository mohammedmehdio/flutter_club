import 'package:cloud_firestore/cloud_firestore.dart';

class Course {
  final String id;
  final String name;
  final String description;
  final String
      instructor; // Changed from coachName to align with common terminology
  final DateTime? dateTime; // Made nullable
  final int durationMinutes;
  final String location; // e.g., "Studio 1", "Online" - Added, was missing
  final int maxCapacity;
  final List<String> enrolledUids; // List of member UIDs enrolled
  final String category; // e.g., "Yoga", "HIIT", "Dance" - Added, was missing
  final String
      difficultyLevel; // e.g., "Beginner", "Intermediate", "Advanced" - Added, was missing
  final double price; // Added
  final List<String> tags; // Added
  final bool isActive; // Added
  final DateTime? endDate; // Added, nullable

  Course({
    required this.id,
    required this.name,
    required this.description,
    required this.instructor,
    this.dateTime, // Made nullable
    required this.durationMinutes,
    required this.location,
    required this.maxCapacity,
    this.enrolledUids = const [],
    required this.category,
    required this.difficultyLevel,
    required this.price,
    this.tags = const [],
    this.isActive = true,
    this.endDate,
  });

  factory Course.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    DateTime? parseTimestamp(dynamic timestampField) {
      if (timestampField is Timestamp) {
        return timestampField.toDate();
      }
      return null;
    }

    // Try to get 'dateTime', fallback to 'startDate' for compatibility with script
    dynamic mainTimestampData = data['dateTime'] ?? data['startDate'];

    return Course(
      id: doc.id,
      name: data['name'] ?? 'Unnamed Course',
      description: data['description'] ?? 'No description available.',
      instructor: data['coachName'] ??
          data['instructor'] ??
          'N/A', // Fallback for coachName
      dateTime: parseTimestamp(mainTimestampData),
      durationMinutes: data['durationMinutes'] ?? 60,
      location: data['location'] ?? 'To be announced',
      maxCapacity: data['maxCapacity'] ?? 0,
      enrolledUids: List<String>.from(data['enrolledUids'] ?? []),
      category: data['category'] ?? 'General',
      difficultyLevel: data['difficultyLevel'] ?? 'All Levels',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      tags: List<String>.from(data['tags'] ?? []),
      isActive: data['isActive'] ?? true,
      endDate: parseTimestamp(data['endDate']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'instructor': instructor,
      'dateTime': dateTime != null ? Timestamp.fromDate(dateTime!) : null,
      'durationMinutes': durationMinutes,
      'location': location,
      'maxCapacity': maxCapacity,
      'enrolledUids': enrolledUids,
      'category': category,
      'difficultyLevel': difficultyLevel,
      'price': price,
      'tags': tags,
      'isActive': isActive,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      // Ensure 'id' and 'createdAt' are not part of toFirestore if managed by Firestore/script
    };
  }
}
