import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();
  final _firestore = FirestoreService();

  User? _user;
  bool _isLoading = true;
  String? _error;

  AuthProvider() {
    _service.authStateChanges.listen((user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// [identifier] lehet felhasználónév vagy e-mail cím
  Future<bool> signIn(String identifier, String password) async {
    _error = null;
    try {
      String email = identifier;
      if (!identifier.contains('@')) {
        final found = await _firestore
            .getEmailByUsername(identifier)
            .timeout(const Duration(seconds: 10));
        if (found == null) {
          _error = 'Nem található ilyen felhasználónév.';
          notifyListeners();
          return false;
        }
        email = found;
      }
      await _service.signIn(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code);
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Hálózati hiba. Ellenőrizd az internetkapcsolatot.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(
      String email, String password, String username) async {
    _error = null;
    try {
      final taken = await _firestore
          .isUsernameTaken(username)
          .timeout(const Duration(seconds: 10));
      if (taken) {
        _error = 'Ez a felhasználónév már foglalt.';
        notifyListeners();
        return false;
      }
      final cred = await _service.register(email, password);
      await _service.updateDisplayName(username);
      await _firestore.saveUserData(cred.user!.uid, email, username);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code);
      notifyListeners();
      return false;
    } catch (_) {
      _error = 'Hálózati hiba. Ellenőrizd az internetkapcsolatot.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _error = null;
    try {
      final result = await _service.signInWithGoogle();
      return result != null;
    } on FirebaseAuthException catch (e) {
      _error = _mapError(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Google bejelentkezés sikertelen: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() => _service.signOut();

  String _mapError(String code) => switch (code) {
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Helytelen e-mail vagy jelszó.',
        'email-already-in-use' => 'Ez az e-mail cím már foglalt.',
        'weak-password' =>
          'A jelszónak legalább 6 karakter hosszúnak kell lennie.',
        _ => 'Hiba történt. Próbáld újra.',
      };
}
