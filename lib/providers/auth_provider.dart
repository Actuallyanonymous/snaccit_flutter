import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _firebaseUser;
  UserModel? _userProfile;
  bool _isLoading = false;
  String? _signUpVerificationId;
  String? _resetVerificationId;
  StreamSubscription<DocumentSnapshot>? _profileSubscription;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _firebaseUser != null;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) {
    _firebaseUser = user;
    if (user != null) {
      _listenToUserProfile();
      _setupNotifications(user.uid);
    } else {
      _profileSubscription?.cancel();
      _userProfile = null;
    }
    notifyListeners();
  }

  void _setupNotifications(String uid) {
    final notifService = NotificationService();
    notifService.saveTokenToFirestore(uid);
    notifService.onTokenRefresh((newToken) => updateFcmToken(newToken));
  }

  void _listenToUserProfile() {
    _profileSubscription?.cancel();
    if (_firebaseUser == null) return;
    _profileSubscription = _firestore
        .collection('users')
        .doc(_firebaseUser!.uid)
        .snapshots()
        .listen(
          (doc) {
            if (doc.exists) {
              _userProfile = UserModel.fromFirestore(doc);
              notifyListeners();
            }
          },
          onError: (e) => debugPrint('Error listening to user profile: $e'),
        );
  }

  // ─── SIGN UP: Send OTP ───
  Future<void> sendSignUpOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    final formatted = phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber';

    await _auth.verifyPhoneNumber(
      phoneNumber: formatted,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-verification (Android only)
        try {
          final result = await _auth.signInWithCredential(credential);
          _isLoading = false;
          notifyListeners();
          // Auto-complete: treat as new user flow (rare path)
          onCodeSent(result.user?.uid ?? '');
        } catch (e) {
          _isLoading = false;
          notifyListeners();
          onError('Auto-verification failed. Please enter OTP manually.');
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        _isLoading = false;
        notifyListeners();
        if (e.code == 'invalid-phone-number') {
          onError('Invalid phone number. Include country code (e.g. +91).');
        } else if (e.code == 'too-many-requests') {
          onError('Too many requests. Please try again later.');
        } else {
          onError(e.message ?? 'Verification failed. Please try again.');
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _signUpVerificationId = verificationId;
        _isLoading = false;
        notifyListeners();
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _signUpVerificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  // ─── SIGN UP: Verify OTP → returns true if new user, false if already registered ───
  Future<bool?> verifySignUpOtp({
    required String smsCode,
    required Function(String error) onError,
  }) async {
    if (_signUpVerificationId == null) {
      onError('Verification session expired. Please request OTP again.');
      return null;
    }
    _isLoading = true;
    notifyListeners();
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _signUpVerificationId!,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      _isLoading = false;
      notifyListeners();
      return result.additionalUserInfo?.isNewUser ?? false;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'invalid-verification-code') {
        onError('Invalid OTP. Please try again.');
      } else if (e.code == 'session-expired') {
        onError('OTP expired. Please request a new one.');
      } else {
        onError(e.message ?? 'Verification failed.');
      }
      return null;
    }
  }

  // ─── SIGN UP: Complete – link email/password + save profile ───
  Future<bool> completeSignUp({
    required String name,
    required String password,
    String? referralCode,
    required Function(String error) onError,
  }) async {
    if (_auth.currentUser == null) {
      onError('Session expired. Please try again.');
      return false;
    }
    _isLoading = true;
    notifyListeners();

    try {
      final phone = _auth.currentUser!.phoneNumber!;
      final dummyEmail = '${phone.replaceAll('+', '')}@snaccit-user.com';

      // Validate referral code if provided
      String? referredByUid;
      if (referralCode != null && referralCode.trim().isNotEmpty) {
        final snapshot = await _firestore
            .collection('users')
            .where('myReferralCode', isEqualTo: referralCode.trim().toUpperCase())
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) {
          _isLoading = false;
          notifyListeners();
          onError('Invalid referral code. Please check and try again.');
          return false;
        }
        if (snapshot.docs.first.id == _auth.currentUser!.uid) {
          _isLoading = false;
          notifyListeners();
          onError('You cannot use your own referral code.');
          return false;
        }
        referredByUid = snapshot.docs.first.id;
      }

      // Generate referral code for this user
      final trimmedName = name.trim();
      final cleanName = trimmedName
          .replaceAll(RegExp(r'[^a-zA-Z]'), '')
          .substring(0, trimmedName.replaceAll(RegExp(r'[^a-zA-Z]'), '').length.clamp(0, 3))
          .toUpperCase();
      final uidSuffix = _auth.currentUser!.uid
          .substring(_auth.currentUser!.uid.length - 5)
          .toUpperCase();
      final myReferralCode = '$cleanName$uidSuffix';

      // Link email/password credential to phone auth user
      final credential = EmailAuthProvider.credential(
        email: dummyEmail,
        password: password,
      );
      await _auth.currentUser!.linkWithCredential(credential);

      // Save profile to Firestore
      await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
        'name': trimmedName,
        'username': trimmedName,
        'phoneNumber': phone,
        'phone': phone,
        'mobile': phone,
        'createdAt': FieldValue.serverTimestamp(),
        'myReferralCode': myReferralCode,
        'referredBy': referredByUid,
        'rewardsIssued': false,
        'points': 0,
      }, SetOptions(merge: true));

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'credential-already-in-use' || e.code == 'email-already-in-use') {
        await _auth.signOut();
        onError('This number already has an account. Please log in.');
      } else if (e.code == 'weak-password') {
        onError('Password must be at least 6 characters.');
      } else {
        onError(e.message ?? 'Sign up failed. Please try again.');
      }
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError('An error occurred. Please try again.');
      return false;
    }
  }

  // ─── LOGIN: Phone + Password ───
  Future<bool> loginWithPhoneAndPassword({
    required String phoneNumber,
    required String password,
    required Function(String errorMessage) onError,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south2')
          .httpsCallable('getPhoneAuthEmail');
      final result = await callable.call({'phoneNumber': phoneNumber});
      final String email = result.data['email'];
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        onError('Incorrect phone number or password.');
      } else {
        onError(e.message ?? 'Login failed. Please try again.');
      }
      return false;
    } on FirebaseFunctionsException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'not-found') {
        onError('No account found for this phone number. Please sign up.');
      } else {
        onError('Could not connect. Please try again.');
      }
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError('An error occurred. Please try again.');
      return false;
    }
  }

  // ─── FORGOT PASSWORD: Send OTP ───
  Future<void> sendResetOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    final formatted = phoneNumber.startsWith('+') ? phoneNumber : '+91$phoneNumber';

    await _auth.verifyPhoneNumber(
      phoneNumber: formatted,
      verificationCompleted: (PhoneAuthCredential credential) async {
        _isLoading = false;
        notifyListeners();
      },
      verificationFailed: (FirebaseAuthException e) {
        _isLoading = false;
        notifyListeners();
        if (e.code == 'too-many-requests') {
          onError('Too many requests. Please try again later.');
        } else {
          onError(e.message ?? 'Verification failed. Please try again.');
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _resetVerificationId = verificationId;
        _isLoading = false;
        notifyListeners();
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _resetVerificationId = verificationId;
      },
      timeout: const Duration(seconds: 60),
    );
  }

  // ─── FORGOT PASSWORD: Verify OTP + Reset Password ───
  Future<bool> resetPasswordWithOtp({
    required String smsCode,
    required String newPassword,
    required Function(String error) onError,
  }) async {
    if (_resetVerificationId == null) {
      onError('Session expired. Please request OTP again.');
      return false;
    }
    _isLoading = true;
    notifyListeners();
    try {
      // Sign in with phone OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: _resetVerificationId!,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);

      // Call cloud function to reset password (handles both old and new-style users)
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south2')
          .httpsCallable('resetPasswordWithPhone');
      await callable.call({'newPassword': newPassword});

      // Sign out — user needs to log in with new password
      await _auth.signOut();

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'invalid-verification-code') {
        onError('Invalid OTP. Please try again.');
      } else if (e.code == 'session-expired') {
        onError('OTP expired. Please request a new one.');
      } else {
        onError(e.message ?? 'Verification failed.');
      }
      return false;
    } on FirebaseFunctionsException catch (e) {
      _isLoading = false;
      notifyListeners();
      onError(e.message ?? 'Failed to reset password. Please try again.');
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError('An error occurred. Please try again.');
      return false;
    }
  }

  // ─── Update Profile ───
  Future<void> updateProfile({String? name, String? email}) async {
    if (_firebaseUser == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final updates = <String, dynamic>{};
      if (name != null) { updates['name'] = name; updates['username'] = name; }
      if (email != null) updates['email'] = email;
      await _firestore.collection('users').doc(_firebaseUser!.uid).update(updates);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ─── Update FCM Token ───
  Future<void> updateFcmToken(String token) async {
    if (_firebaseUser == null) return;
    try {
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({'fcmToken': token});
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // ─── Sign Out ───
  Future<void> signOut() async {
    if (_firebaseUser != null) {
      await NotificationService().removeToken(_firebaseUser!.uid);
    }
    _profileSubscription?.cancel();
    await _auth.signOut();
    _userProfile = null;
    _signUpVerificationId = null;
    _resetVerificationId = null;
    notifyListeners();
  }
}
