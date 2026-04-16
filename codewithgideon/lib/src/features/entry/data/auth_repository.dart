import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EnrollmentStatus { enrolled, pending, notRegistered }

class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.accessToken,
    required this.enrollmentStatus,
    required this.isEmailVerified,
  });

  final String uid;
  final String email;
  final String accessToken;
  final EnrollmentStatus enrollmentStatus;
  final bool isEmailVerified;

  AuthSession copyWith({
    String? uid,
    String? email,
    String? accessToken,
    EnrollmentStatus? enrollmentStatus,
    bool? isEmailVerified,
  }) {
    return AuthSession(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      accessToken: accessToken ?? this.accessToken,
      enrollmentStatus: enrollmentStatus ?? this.enrollmentStatus,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'accessToken': accessToken,
      'enrollmentStatus': enrollmentStatus.name,
      'isEmailVerified': isEmailVerified,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      uid: json['uid'] as String? ?? 'demo-user',
      email: json['email'] as String,
      accessToken: json['accessToken'] as String,
      enrollmentStatus: EnrollmentStatus.values.firstWhere(
        (item) => item.name == json['enrollmentStatus'],
        orElse: () => EnrollmentStatus.enrolled,
      ),
      isEmailVerified: json['isEmailVerified'] as bool? ?? false,
    );
  }
}

class AuthRepository {
  AuthRepository({
    required SharedPreferences preferences,
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firebaseFirestore,
  }) : _preferences = preferences,
       _firebaseAuth = firebaseAuth,
       _firebaseFirestore = firebaseFirestore;

  final SharedPreferences _preferences;
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firebaseFirestore;

  static const _onboardingSeenKey = 'auth.onboarding_seen';

  Future<AuthSession?> restoreSession() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return _buildSession(user);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: normalizedPassword,
    );
    await markOnboardingSeen();
    return _buildSession(credential.user!);
  }

  Future<AuthSession> createAccount({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    await markOnboardingSeen();
    try {
      await credential.user?.sendEmailVerification();
    } on FirebaseAuthException {
      // The verification screen can resend if the first attempt fails.
    }
    final token = await credential.user?.getIdToken() ?? '';
    return AuthSession(
      uid: credential.user!.uid,
      email: credential.user!.email ?? email.trim(),
      accessToken: token,
      enrollmentStatus: EnrollmentStatus.notRegistered,
      isEmailVerified: credential.user?.emailVerified ?? false,
    );
  }

  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('Your session expired. Please sign in again.');
    }

    await user.sendEmailVerification();
  }

  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }

  Future<void> persistSession(AuthSession session) async {}

  bool hasSeenOnboarding() => _preferences.getBool(_onboardingSeenKey) ?? false;

  Future<void> markOnboardingSeen() async {
    await _preferences.setBool(_onboardingSeenKey, true);
  }

  Future<AuthSession> _buildSession(User user) async {
    try {
      await user.reload();
    } on FirebaseAuthException {
      // Fall back to the cached user so offline launches do not force logout.
    }
    final refreshedUser = _firebaseAuth.currentUser ?? user;
    final token = await refreshedUser.getIdToken(true) ?? '';
    final doc = await _firebaseFirestore
        .collection('users')
        .doc(refreshedUser.uid)
        .get();
    final data = doc.data();
    final pendingPayment = data?['pendingPayment'];
    final hasPendingInitialPayment =
        pendingPayment is Map &&
        pendingPayment['status'] == 'Pending' &&
        pendingPayment['kind'] != 'topup';
    final status = data?['status'];

    final enrollmentStatus = !doc.exists
        ? EnrollmentStatus.notRegistered
        : status == 'Pending' || hasPendingInitialPayment
        ? EnrollmentStatus.pending
        : EnrollmentStatus.enrolled;

    return AuthSession(
      uid: refreshedUser.uid,
      email: refreshedUser.email ?? '',
      accessToken: token,
      enrollmentStatus: enrollmentStatus,
      isEmailVerified: refreshedUser.emailVerified,
    );
  }
}
