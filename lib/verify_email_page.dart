import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main.dart';
import 'ecran_verification_client.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;
  final String role; // ✅ NOUVEAU : 'client' ou 'artisan'

  const VerifyEmailPage({
    super.key,
    required this.email,
    this.role = 'client', // ✅ Par défaut client
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  bool _isLoading = false;

  Future<void> _checkEmailVerified() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.currentUser!.reload();
      User? user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        if (mounted) {
          // ✅ Redirection selon le rôle
          if (widget.role == 'artisan') {
            // L'artisan va créer sa fiche
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const EcranProfessionnel(),
              ),
            );
          } else {
            // Le client passe d'abord par la vérification de fiabilité.
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const EcranVerificationClient(),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Votre e-mail n\'est pas encore vérifié. Vérifiez votre boîte mail.'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _renvoyerEmail() async {
    try {
      await FirebaseAuth.instance.currentUser!.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de vérification renvoyé !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool estArtisan = widget.role == 'artisan';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification de l\'e-mail'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône selon le rôle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                estArtisan ? Icons.handyman_rounded : Icons.email_rounded,
                size: 55,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 24),

            // Badge rôle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: estArtisan ? Colors.amber.shade100 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: estArtisan ? Colors.amber : Colors.blueAccent.withOpacity(0.3),
                ),
              ),
              child: Text(
                estArtisan ? '🔧 Inscription Artisan' : '👤 Inscription Client',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: estArtisan ? Colors.amber.shade800 : Colors.blueAccent,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Un e-mail de validation a été envoyé à ${widget.email}.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 10),
            Text(
  estArtisan
      ? 'Après vérification, vous pourrez créer votre fiche artisan.'
      : 'Vérifiez votre boîte mail et cliquez sur le lien de validation.',
  textAlign: TextAlign.center,
  style: const TextStyle(color: Colors.grey, fontSize: 14),
),
const SizedBox(height: 8),
// ✅ NOUVEAU : mention spams
Row(
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
    const SizedBox(width: 5),
    const Flexible(
      child: Text(
        'Veillez également à vérifier vos spams, le mail peut s\'y trouver.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.orange, fontSize: 12),
      ),
    ),
  ],
),

            const SizedBox(height: 40),

            // Bouton principal
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _checkEmailVerified,
                icon: const Icon(Icons.check_circle_outline),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('J\'ai vérifié mon mail',
                        style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Bouton renvoyer email
            TextButton.icon(
              onPressed: _renvoyerEmail,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Renvoyer l\'email de vérification'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}