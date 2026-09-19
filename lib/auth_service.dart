import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Fonction d'inscription avec e-mail et mot de passe
  Future<User?> signUpWithEmail(
    String email,
    String password,
    String fullName, {
    String role = 'client',
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await result.user!.sendEmailVerification();

      // Enregistrer le nom complet dans la collection users
      await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
        'fullName': fullName,
        'email': email,
        'role': role,
        'statutVerification': role == 'client' ? 'non_soumis' : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return result.user;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw 'Cet e-mail est déjà utilisé.';
        case 'invalid-email':
          throw 'Adresse e-mail invalide.';
        case 'weak-password':
          throw 'Le mot de passe est trop faible.';
        default:
          throw 'Erreur lors de l\'inscription : ${e.message}';
      }
    } catch (e) {
      throw 'Erreur inconnue : $e';
    }
  }

  // Fonction de connexion avec e-mail et mot de passe
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw 'Aucun utilisateur trouvé avec cet e-mail.';
        case 'wrong-password':
        case 'invalid-credential':
          throw 'Mot de passe incorrect.';
        case 'invalid-email':
          throw 'Adresse e-mail invalide.';
        case 'user-disabled':
          throw 'Ce compte utilisateur a été désactivé.';
        default:
          throw 'Erreur lors de la connexion : ${e.message}';
      }
    } catch (e) {
      throw 'Erreur inconnue : $e';
    }
  }

  // Fonction de réinitialisation du mot de passe
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          throw 'Adresse e-mail invalide.';
        case 'user-not-found':
          throw 'Aucun utilisateur trouvé avec cet e-mail.';
        default:
          throw 'Erreur lors de l\'envoi du lien de réinitialisation : ${e.message}';
      }
    } catch (e) {
      throw 'Erreur inconnue : $e';
    }
  }

  // Getter pour l'utilisateur actuel
  User? get currentUser => _auth.currentUser;

  // Stream pour écouter les changements d'état d'authentification
  Stream<User?> get userStream => _auth.authStateChanges();
}