import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? phone;
  final String name;
  final String? referralCode;
  final int points;
  final String? fcmToken;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    this.email,
    this.phone,
    required this.name,
    this.referralCode,
    this.points = 0,
    this.fcmToken,
    this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'],
      phone: data['phone'] ?? data['phoneNumber'] ?? data['mobile'],
      name: data['name'] ?? data['username'] ?? 'Customer',
      referralCode: data['referralCode'] ?? data['myReferralCode'],
      points: data['points'] ?? 0,
      fcmToken: data['fcmToken'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'phone': phone,
      'name': name,
      'referralCode': referralCode,
      'points': points,
      'fcmToken': fcmToken,
    };
  }
}
