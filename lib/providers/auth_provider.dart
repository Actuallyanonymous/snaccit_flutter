import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/user.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _firebaseUser;
  UserModel? _userProfile;
  bool _isLoading = false;
  String? _verificationId;
  int? _resendToken;

  User? get firebaseUser => _firebaseUser;
  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _firebaseUser != null;
  String? get verificationId => _verificationId;

  AuthProvider() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  void _onAuthStateChanged(User? user) async {
    _firebaseUser = user;
    if (user != null) {
      await _loadUserProfile();
    } else {
      _userProfile = null;
    }
    notifyListeners();
  }

  Future<void> _loadUserProfile() async {
    if (_firebaseUser == null) return;
    
    try {
      final doc = await _firestore.collection('users').doc(_firebaseUser!.uid).get();
      if (doc.exists) {
        _userProfile = UserModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  // Check if phone exists
  Future<bool> checkPhoneExists(String phoneNumber) async {
    _isLoading = true;
    notifyListeners();
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south2')
          .httpsCallable('preparePhoneSignup');
      final result = await callable.call({
        'phoneNumber': phoneNumber,
        'password': 'dummy', // Just to check existence
        'name': 'dummy',
      });
      _isLoading = false;
      notifyListeners();
      return result.data['exists'] == true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.toString().contains('already exists')) return true;
      return false; // Assume false if error, to allow signup attempt
    }
  }

  // Sign up with Phone & Password
  Future<bool> signUpWithPhoneAndPassword({
    required String phoneNumber,
    required String password,
    required String name,
    required Function(String errorMessage) onError,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-south2')
          .httpsCallable('preparePhoneSignup');
      final result = await callable.call({
        'phoneNumber': phoneNumber,
        'password': password,
        'name': name,
      });

      if (result.data['exists'] == true) {
        throw Exception(result.data['message'] ?? 'Account already exists.');
      }

      final String dummyEmail = result.data['email'];

      // Now login with the created dummy email
      await _auth.signInWithEmailAndPassword(
        email: dummyEmail,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  // Login with Phone & Password
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
      final result = await callable.call({
        'phoneNumber': phoneNumber,
      });

      final String email = result.data['email'];

      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        onError('Invalid phone number or password.');
      } else {
        onError(e.message ?? 'Login failed. Please try again.');
      }
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      onError('Error connecting to server. Please try again.');
      return false;
    }
  }

  // Update user profile
  Future<void> updateProfile({String? name, String? email}) async {
    if (_firebaseUser == null) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final updates = <String, dynamic>{};
      if (name != null) {
        updates['name'] = name;
        updates['username'] = name;
      }
      if (email != null) updates['email'] = email;
      
      await _firestore.collection('users').doc(_firebaseUser!.uid).update(updates);
      await _loadUserProfile();
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Update FCM token
  Future<void> updateFcmToken(String token) async {
    if (_firebaseUser == null) return;
    
    try {
      await _firestore.collection('users').doc(_firebaseUser!.uid).update({
        'fcmToken': token,
      });
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    _userProfile = null;
    _verificationId = null;
    notifyListeners();
  }
}
