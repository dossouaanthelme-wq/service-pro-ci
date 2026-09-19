import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'main.dart';
import 'ecran_verification_client.dart';

String? formaterNumeroIvoirien(String numero) {
  final telephone = numero.trim();
  final regexCI = RegExp(r'^(?:01|05|07|25|27)\d{8}$');
  if (!regexCI.hasMatch(telephone)) return null;
  return '+225$telephone';
}

String? determinerOperateur(String numeroFormate) {
  final local = numeroFormate.startsWith('+225')
      ? numeroFormate.substring(4)
      : numeroFormate;
  if (local.length < 2) return null;
  final prefixe = local.substring(0, 2);
  const moov = ['01', '02', '03'];
  const mtn = ['04', '05', '06'];
  const orange = ['07', '08', '09'];
  if (moov.contains(prefixe)) return 'moov';
  if (mtn.contains(prefixe)) return 'mtn';
  if (orange.contains(prefixe)) return 'orange';
  return null;
}

class EcranAuthTelephone extends StatefulWidget {
  const EcranAuthTelephone({super.key});

  @override
  State<EcranAuthTelephone> createState() => _EcranAuthTelephoneState();
}

class _EcranAuthTelephoneState extends State<EcranAuthTelephone> {
  String _etape = 'telephone';

  final _telephoneController = TextEditingController();
  final _codeController      = TextEditingController();
  final _nomController       = TextEditingController();
  final _prenomController    = TextEditingController();
  final _motDePasseController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _motDePasseVisible = false;
  bool _confirmationVisible = false;

  String  _roleChoisi     = 'client';
  String? _verificationId;
  bool    _enChargement   = false;
  bool    _utiliseLeTexto = false;

  // ── Étape 1 : Envoyer le SMS ──────────────────────────────────────
  Future<void> _envoyerSMS() async {
    final telephone = _telephoneController.text.trim();
    final numeroFormate = formaterNumeroIvoirien(telephone);
    if (numeroFormate == null) {
      _afficherErreur(
        'Numéro invalide. Formats acceptés : 01, 05, 07, 25 ou 27 suivis de 8 chiffres.',
      );
      return;
    }

    final operateur = determinerOperateur(numeroFormate);

    setState(() => _enChargement = true);

    if (operateur == 'orange' || operateur == 'moov') {
      await _envoyerOtpLeTexto(numeroFormate);
      return;
    }

    // ✅ NE PAS utiliser forceRecaptchaFlow sur Android — ça bloque le SMS
    // Firebase gère automatiquement la vérification via Play Integrity

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: numeroFormate,
      timeout: const Duration(seconds: 120),

      // ✅ SMS envoyé avec succès
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _etape          = 'code';
          _enChargement   = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Code SMS envoyé au $numeroFormate'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },

      // ✅ Android détecte le code automatiquement (pas besoin de le saisir)
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _connecterAvecCredential(credential);
      },

      // ✅ Gestion précise des erreurs
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _enChargement = false);

        String message;
        switch (e.code) {
          case 'invalid-phone-number':
            message = 'Numéro invalide. Format attendu : un numéro ivoirien à 10 chiffres.';
            break;
          case 'too-many-requests':
            message = 'Trop de tentatives. Réessayez dans quelques minutes.';
            break;
          case 'app-not-authorized':
            message = 'Application non autorisée. Détail: ${e.message}';
            break;
          case 'quota-exceeded':
            message = 'Quota SMS Firebase dépassé. Réessayez demain.';
            break;
          case 'billing-not-enabled':
            message = 'Activez la facturation Firebase (plan Blaze requis).';
            break;
          case 'missing-client-identifier':
            message = 'Erreur SHA. Vérifiez vos empreintes dans Firebase Console.';
            break;
          default:
            message = 'Erreur (${e.code}) : ${e.message}';
        }
        debugPrint(e.code);
        debugPrint(e.message);
        _afficherErreur(message);
      },

      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
        if (mounted && _enChargement) {
          setState(() => _enChargement = false);
        }
      },
    );
  }

  Future<void> _envoyerOtpLeTexto(String numeroFormate) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'genererEtEnvoyerOtpLeTexto',
      );
      await callable.call({'telephone': numeroFormate});

      if (!mounted) return;
      setState(() {
        _utiliseLeTexto = true;
        _etape          = 'code';
        _enChargement   = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Code SMS envoyé au $numeroFormate'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _enChargement = false);
      _afficherErreur(e.message ?? 'Erreur lors de l\'envoi du code (${e.code})');
    } catch (e) {
      if (!mounted) return;
      setState(() => _enChargement = false);
      _afficherErreur('Erreur inattendue : $e');
    }
  }

  // ── Étape 2 : Vérifier le code SMS ───────────────────────────────
  Future<void> _verifierCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || code.length != 6) {
      _afficherErreur('Le code doit contenir 6 chiffres');
      return;
    }

    if (_utiliseLeTexto) {
      await _verifierOtpLeTexto(code);
      return;
    }

    if (_verificationId == null) {
      _afficherErreur('Session expirée. Recommencez.');
      return;
    }

    setState(() => _enChargement = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _connecterAvecCredential(credential);
    } on FirebaseAuthException catch (e) {
      setState(() => _enChargement = false);
      if (e.code == 'invalid-verification-code') {
        _afficherErreur('Code incorrect. Vérifiez et réessayez.');
      } else if (e.code == 'session-expired') {
        _afficherErreur('Session expirée. Renvoyez le SMS.');
        setState(() => _etape = 'telephone');
      } else {
        _afficherErreur('Erreur : ${e.code}');
      }
    } catch (e) {
      setState(() => _enChargement = false);
      _afficherErreur('Erreur inattendue : $e');
    }
  }

  Future<void> _verifierOtpLeTexto(String code) async {
    final numeroFormate = formaterNumeroIvoirien(_telephoneController.text);
    if (numeroFormate == null) {
      _afficherErreur('Session téléphone invalide. Recommencez.');
      return;
    }

    setState(() => _enChargement = true);

    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'verifierOtpLeTexto',
      );
      final result = await callable.call({
        'telephone': numeroFormate,
        'code': code,
      });

      final customToken = result.data['customToken'] as String?;
      if (customToken == null) {
        throw Exception('Réponse invalide du serveur');
      }

      final userCredential =
          await FirebaseAuth.instance.signInWithCustomToken(customToken);
      final user = userCredential.user;
      if (user == null) return;

      await _apresConnexionReussie(user);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() => _enChargement = false);
      _afficherErreur(e.message ?? 'Erreur (${e.code})');
    } catch (e) {
      if (!mounted) return;
      setState(() => _enChargement = false);
      _afficherErreur('Erreur inattendue : $e');
    }
  }

  // ── Connexion avec credential ─────────────────────────────────────
  Future<void> _connecterAvecCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return;
      await _apresConnexionReussie(user);
    } on FirebaseAuthException catch (e) {
      setState(() => _enChargement = false);
      _afficherErreur('Erreur connexion : ${e.code}');
    } catch (e) {
      setState(() => _enChargement = false);
      _afficherErreur('Erreur : $e');
    }
  }

  Future<void> _apresConnexionReussie(User user) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    final userData = userDoc.data();
    final emailSynthetique = userData?['emailSynthetique'];
    final motDePasseDejaCree =
        emailSynthetique is String && emailSynthetique.isNotEmpty;

    if (userDoc.exists && motDePasseDejaCree) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EcranProfil()),
        );
      } else {
        setState(() {
          _etape        = 'mot_de_passe';
          _enChargement = false;
        });
    }
  }

  // ── Étape 3 : Finaliser l'inscription ────────────────────────────
  Future<void> _finaliserInscription() async {
    if (_nomController.text.trim().isEmpty) {
      _afficherErreur('Veuillez entrer votre nom');
      return;
    }
    if (_prenomController.text.trim().isEmpty) {
      _afficherErreur('Veuillez entrer votre prénom');
      return;
    }

    setState(() => _enChargement = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
        final numeroFormate = formaterNumeroIvoirien(_telephoneController.text);
        final emailSynthetique = numeroFormate == null
          ? null
          : '${numeroFormate.substring(1)}@serviceproci.app';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'nom':       _nomController.text.trim(),
        'prenom':    _prenomController.text.trim(),
        'fullName':  '${_prenomController.text.trim()} ${_nomController.text.trim()}',
        'telephone': _telephoneController.text.trim(),
        'emailSynthetique': emailSynthetique,
        'role':      _roleChoisi,
        'statutVerification': _roleChoisi == 'client' ? 'non_soumis' : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      if (_roleChoisi == 'artisan') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const EcranProfessionnel()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const EcranVerificationClient(),
          ),
        );
      }
    } catch (e) {
      setState(() => _enChargement = false);
      _afficherErreur('Erreur lors de l\'enregistrement : $e');
    }
  }

  Future<void> _lierMotDePasseTelephone() async {
    final motDePasse = _motDePasseController.text;
    final confirmation = _confirmationController.text;
    if (motDePasse.length < 6) {
      _afficherErreur('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    if (motDePasse != confirmation) {
      _afficherErreur('Les mots de passe ne correspondent pas');
      return;
    }

    setState(() => _enChargement = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final numeroFormate = formaterNumeroIvoirien(_telephoneController.text);
      if (user == null || numeroFormate == null) {
        _afficherErreur('Session téléphone invalide. Recommencez.');
        setState(() => _enChargement = false);
        return;
      }

      final emailSynthetique = '${numeroFormate.substring(1)}@serviceproci.app';
      final credential = EmailAuthProvider.credential(
        email: emailSynthetique,
        password: motDePasse,
      );
      await user.linkWithCredential(credential);
      setState(() {
        _etape = 'role';
        _enChargement = false;
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _enChargement = false);
      if (e.code == 'credential-already-in-use') {
        _afficherErreur('Ce numéro possède déjà un mot de passe. Connectez-vous avec le mode Numéro.');
      } else if (e.code == 'weak-password') {
        _afficherErreur('Le mot de passe doit contenir au moins 6 caractères');
      } else {
        _afficherErreur('Impossible de définir le mot de passe : ${e.message ?? e.code}');
      }
    } catch (e) {
      setState(() => _enChargement = false);
      _afficherErreur('Erreur lors de la création du mot de passe : $e');
    }
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion par téléphone'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _IndicateurEtapes(etapeActuelle: _etape),
            const SizedBox(height: 32),
            if (_etape == 'telephone') _buildEtapeTelephone(),
            if (_etape == 'code')      _buildEtapeCode(),
            if (_etape == 'mot_de_passe') _buildEtapeMotDePasse(),
            if (_etape == 'role')      _buildEtapeRole(),
          ],
        ),
      ),
    );
  }

  Widget _buildEtapeTelephone() {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: Colors.blueAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.phone_android, size: 40, color: Colors.blueAccent),
        ),
        const SizedBox(height: 20),
        const Text('Entrez votre numéro',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text(
          'Vous recevrez un code SMS de vérification',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _telephoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: InputDecoration(
            labelText: 'Numéro de téléphone',
            border: const OutlineInputBorder(),
            prefixIcon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇨🇮', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text('+225',
                      style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(width: 4),
                  Container(width: 1, height: 20, color: Colors.grey.shade300),
                ],
              ),
            ),
            hintText: '07 XX XX XX XX',
            counterText: '',
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _enChargement ? null : _envoyerSMS,
            icon: const Icon(Icons.send_rounded),
            label: _enChargement
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Envoyer le code SMS',
                    style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEtapeCode() {
    return Column(
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sms_rounded, size: 40, color: Colors.green),
        ),
        const SizedBox(height: 20),
        const Text('Code de vérification',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Code envoyé au +225 ${_telephoneController.text}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 12),
          decoration: InputDecoration(
            labelText: 'Code à 6 chiffres',
            border: const OutlineInputBorder(),
            counterText: '',
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _enChargement ? null : _verifierCode,
            icon: const Icon(Icons.check_circle_outline),
            label: _enChargement
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Vérifier le code',
                    style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => setState(() {
            _etape = 'telephone';
            _codeController.clear();
            _utiliseLeTexto = false;
          }),
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Changer de numéro ou renvoyer'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildEtapeMotDePasse() {
    return Column(
      children: [
        const Icon(Icons.lock_outline, size: 80, color: Colors.blueAccent),
        const SizedBox(height: 20),
        const Text('Créez votre mot de passe',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Il vous permettra de vous reconnecter sans recevoir un SMS.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 24),
        TextField(
          controller: _motDePasseController,
          obscureText: !_motDePasseVisible,
          decoration: InputDecoration(
            labelText: 'Mot de passe (6 caractères minimum)',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key),
            suffixIcon: IconButton(
              icon: Icon(_motDePasseVisible
                  ? Icons.visibility
                  : Icons.visibility_off),
              onPressed: () => setState(
                () => _motDePasseVisible = !_motDePasseVisible,
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _confirmationController,
          obscureText: !_confirmationVisible,
          decoration: InputDecoration(
            labelText: 'Confirmer le mot de passe',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.key_outlined),
            suffixIcon: IconButton(
              icon: Icon(_confirmationVisible
                  ? Icons.visibility
                  : Icons.visibility_off),
              onPressed: () => setState(
                () => _confirmationVisible = !_confirmationVisible,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _enChargement ? null : _lierMotDePasseTelephone,
            icon: const Icon(Icons.check_circle_outline),
            label: _enChargement
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Continuer', style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEtapeRole() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text('Finalisez votre inscription',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 24),
        const Text('Je suis un...',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildCarteRole('client', Icons.search_rounded, 'CLIENT')),
            const SizedBox(width: 12),
            Expanded(child: _buildCarteRole('artisan', Icons.handyman_rounded, 'ARTISAN')),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nomController,
          decoration: const InputDecoration(
            labelText: 'Nom *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: _prenomController,
          decoration: const InputDecoration(
            labelText: 'Prénom *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton.icon(
            onPressed: _enChargement ? null : _finaliserInscription,
            icon: const Icon(Icons.rocket_launch_rounded),
            label: _enChargement
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Terminer l\'inscription',
                    style: TextStyle(fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCarteRole(String role, IconData icone, String label) {
    final selectionne = _roleChoisi == role;
    return GestureDetector(
      onTap: () => setState(() => _roleChoisi = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selectionne ? Colors.blueAccent : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selectionne ? Colors.blueAccent : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icone,
                color: selectionne ? Colors.white : Colors.grey, size: 28),
            const SizedBox(height: 6),
            Text(label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selectionne ? Colors.white : Colors.grey,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Indicateur d'étapes ───────────────────────────────────────────────
class _IndicateurEtapes extends StatelessWidget {
  final String etapeActuelle;
  const _IndicateurEtapes({required this.etapeActuelle});

  @override
  Widget build(BuildContext context) {
    final etapes      = ['telephone', 'code', 'mot_de_passe', 'role'];
    final labels      = ['Téléphone', 'Vérification', 'Mot de passe', 'Profil'];
    final indexActuel = etapes.indexOf(etapeActuelle);

    return Row(
      children: List.generate(etapes.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
            child: Container(
              height: 2,
              color: i ~/ 2 < indexActuel
                  ? Colors.blueAccent
                  : Colors.grey.shade300,
            ),
          );
        }
        final index = i ~/ 2;
        final actif = index <= indexActuel;
        return Column(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: actif ? Colors.blueAccent : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: actif && index < indexActuel
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text('${index + 1}',
                        style: TextStyle(
                          color: actif ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        )),
              ),
            ),
            const SizedBox(height: 4),
            Text(labels[index],
                style: TextStyle(
                  fontSize: 10,
                  color: actif ? Colors.blueAccent : Colors.grey,
                  fontWeight: actif ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        );
      }),
    );
  }
}