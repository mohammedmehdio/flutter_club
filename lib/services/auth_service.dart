import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Sign up with client code
  Future<UserCredential?> signUpWithClientCode(
      String clientCode, String password) async {
    print(
        '[AuthService] Attempting signUpWithClientCode for clientCode: $clientCode'); // DEBUG
    try {
      // First check if the client code is valid and available
      print(
          '[AuthService] Calling getClientCodeDataIfAvailable for: $clientCode'); // DEBUG
      final Map<String, dynamic>? clientCodeData =
          await _firestoreService.getClientCodeDataIfAvailable(clientCode);
      print('[AuthService] clientCodeData received: $clientCodeData'); // DEBUG

      if (clientCodeData == null) {
        print(
            '[AuthService] Client code $clientCode is invalid, already claimed, or non-existent.'); // DEBUG
        throw Exception(
            'Invalid, already claimed, or non-existent client code.');
      }

      // Determine the email for Firebase Auth.
      String emailForAuth =
          clientCodeData['email'] as String? ?? '$clientCode@yourclub.com';
      print('[AuthService] Email for Firebase Auth: $emailForAuth'); // DEBUG

      // Ensure the email from clientCodeData is a string if it exists
      if (clientCodeData.containsKey('email') &&
          clientCodeData['email'] is! String) {
        print(
            '[AuthService] Email field in client code data is not a string.'); // DEBUG
        throw Exception('Email field in client code data is not a string.');
      }

      print(
          '[AuthService] Calling createUserWithEmailAndPassword for email: $emailForAuth'); // DEBUG
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: emailForAuth,
        password: password,
      );
      print(
          '[AuthService] Firebase Auth user created. UID: ${userCredential.user?.uid}'); // DEBUG

      if (userCredential.user != null) {
        print(
            '[AuthService] Calling createMemberAndClaimClientCode for clientCode: $clientCode, UID: ${userCredential.user!.uid}'); // DEBUG
        await _firestoreService.createMemberAndClaimClientCode(
            clientCode, userCredential.user!.uid, clientCodeData);
        print(
            '[AuthService] createMemberAndClaimClientCode completed successfully.'); // DEBUG
      } else {
        print(
            '[AuthService] Firebase user creation failed (user is null).'); // DEBUG
        // This case should ideally not be reached if createUserWithEmailAndPassword succeeds
        throw Exception('Firebase user creation failed (user is null).');
      }

      print(
          '[AuthService] signUpWithClientCode successful for $clientCode.'); // DEBUG
      return userCredential;
    } catch (e) {
      print(
          '[AuthService] Error in signUpWithClientCode for $clientCode: $e'); // DEBUG
      rethrow;
    }
  }

  // Sign in with client code
  Future<UserCredential?> signInWithClientCode(
      String clientCode, String password) async {
    try {
      print(
          '[AuthService] Attempting signInWithClientCode for clientCode: $clientCode'); // DEBUG

      // Step 1: Fetch the email associated with the clientCode from the 'clientCodes' collection.
      // This email was stored there during the admin member creation process.
      String? emailFromClientCodeDoc =
          await _firestoreService.getEmailByClientCode(clientCode);

      if (emailFromClientCodeDoc == null || emailFromClientCodeDoc.isEmpty) {
        print(
            '[AuthService] Sign-in failed: Email not found or empty in clientCodes collection for $clientCode.'); // DEBUG
        // It's important that the clientCodes document has the correct email.
        // This email is used to create the Firebase Auth user during signup.
        throw Exception('Client code not found or setup incorrectly.');
      }
      print(
          '[AuthService] Email fetched from clientCodes collection for $clientCode: $emailFromClientCodeDoc'); // DEBUG

      // Step 2: Sign in with Firebase Auth using the fetched email and provided password.
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email:
            emailFromClientCodeDoc, // Use the email from the clientCodes document
        password: password,
      );
      print(
          '[AuthService] Firebase signInWithEmailAndPassword successful for email: $emailFromClientCodeDoc'); // DEBUG

      // Step 3: (Optional but good practice) Verify member document exists and update last login.
      // The member document ID is the clientCode.
      if (credential.user != null) {
        try {
          // Fetch member to ensure it exists, though sign-in success implies it should.
          final member =
              await _firestoreService.getMemberByClientCode(clientCode);
          if (member == null) {
            print(
                '[AuthService] Post-signin check: Member document not found for $clientCode. This is unexpected.'); // DEBUG
            // Decide if this is a critical failure. For now, log and continue.
          } else {
            print(
                '[AuthService] Post-signin check: Member document found for $clientCode. UID: ${member.uid}'); // DEBUG
            // Ensure the UID in the member doc matches the signed-in user's UID.
            if (member.uid != credential.user!.uid) {
              print(
                  '[AuthService] CRITICAL: UID mismatch! Member doc UID ${member.uid} vs Auth UID ${credential.user!.uid}'); // DEBUG
              // This indicates a serious data integrity issue.
              // For now, we will throw an exception, but this needs careful handling.
              throw Exception(
                  'User data integrity issue. Please contact support.');
            }
          }
          await _firestoreService.updateLastLogin(clientCode);
          print(
              '[AuthService] Last login updated for $clientCode (memberId)'); // DEBUG
        } catch (e) {
          print(
              '[AuthService] Error during post-signin checks or updating last login for $clientCode (non-critical): $e'); // DEBUG
        }
      }
      print(
          '[AuthService] signInWithClientCode successful for $clientCode. Returning credential.'); // DEBUG
      return credential;
    } catch (e) {
      print(
          '[AuthService] Error in signInWithClientCode for $clientCode: $e'); // DEBUG
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String clientCode) async {
    print(
        '[AuthService] Attempting to send password reset for clientCode: $clientCode');
    try {
      // Attempt to get the member's email from Firestore
      String emailToSend;
      try {
        final memberData =
            await _firestoreService.getMemberByClientCode(clientCode);
        if (memberData != null && memberData.email.isNotEmpty) {
          emailToSend = memberData.email;
          print(
              '[AuthService] Found email for password reset: $emailToSend from Firestore.');
        } else {
          // Fallback if member data or email is not found/empty
          emailToSend = '$clientCode@yourclub.com';
          print(
              '[AuthService] Member data or email not found for $clientCode, using fallback email: $emailToSend');
        }
      } catch (e) {
        // Fallback if there's an error fetching member data
        emailToSend = '$clientCode@yourclub.com';
        print(
            '[AuthService] Error fetching member data for $clientCode, using fallback email: $emailToSend. Error: $e');
      }

      print('[AuthService] Sending password reset email to: $emailToSend');
      await _auth.sendPasswordResetEmail(email: emailToSend);
      print(
          '[AuthService] Password reset email sent successfully to $emailToSend for clientCode $clientCode.');
    } catch (e) {
      print(
          '[AuthService] Error sending password reset email for $clientCode (email tried: any): $e');
      // It's important to check the type of error here.
      // If it's a FirebaseAuthException, e.code can give more specific reasons
      // like 'user-not-found', 'invalid-email', etc.
      if (e is FirebaseAuthException) {
        throw Exception('Failed to send password reset email: ${e.message}');
      }
      throw Exception(
          'An unexpected error occurred while sending the password reset email.');
    }
  }
}
