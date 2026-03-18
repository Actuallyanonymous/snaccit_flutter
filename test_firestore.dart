import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  try {
    final snap = await FirebaseFirestore.instance.collection('users').limit(1).get();
    print('SUCCESS: ${snap.docs.length}');
  } catch (e) {
    print('ERROR: $e');
  }
}
