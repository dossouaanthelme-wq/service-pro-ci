import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';

class EcranVerificationClient extends StatefulWidget {
  const EcranVerificationClient({super.key});

  @override
  State<EcranVerificationClient> createState() =>
      _EcranVerificationClientState();
}

class _EcranVerificationClientState extends State<EcranVerificationClient> {
  final ImagePicker _picker = ImagePicker();
  File? _selfie;
  File? _document;
  String _typeDocument = 'CNI';
  bool _enChargement = false;

  Future<void> _prendreSelfie() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      preferredCameraDevice: CameraDevice.front,
    );
    if (image != null && mounted) {
      setState(() => _selfie = File(image.path));
    }
  }

  Future<void> _choisirDocument() async {
    final document = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (document != null && mounted) {
      setState(() => _document = File(document.path));
    }
  }

  Future<String> _uploaderFichier(String uid, String nom, File fichier) async {
    final reference = FirebaseStorage.instance
        .ref()
        .child('verifications_clients')
        .child(uid)
        .child('$nom.jpg');
    debugPrint('KYC client Storage upload start path=${reference.fullPath}');
    try {
      await reference.putFile(fichier);
      final url = await reference.getDownloadURL();
      debugPrint('KYC client Storage upload success path=${reference.fullPath} url=$url');
      return url;
    } on FirebaseException catch (e) {
      debugPrint(
        'KYC client Storage upload error path=${reference.fullPath} '
        'code=${e.code} message=${e.message} details=${e.toString()}',
      );
      rethrow;
    }
  }

  Future<void> _soumettreVerification() async {
    if (_selfie == null || _document == null) {
      _afficherErreur('Le selfie et le document sont obligatoires.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _afficherErreur('Session expirée. Reconnectez-vous.');
      return;
    }

    setState(() => _enChargement = true);
    try {
      final selfieUrl = await _uploaderFichier(user.uid, 'selfie', _selfie!);
      final documentUrl =
          await _uploaderFichier(user.uid, 'document', _document!);

      final payload = <String, dynamic>{
        'statutVerification': 'en_attente',
        'selfieUrl': selfieUrl,
        'documentUrl': documentUrl,
        'typeDocument': _typeDocument,
        'dateSoumission': FieldValue.serverTimestamp(),
      };
      debugPrint('KYC client uid=${user.uid} payload:');
      payload.forEach((key, value) {
        debugPrint('  $key = $value (type=${value.runtimeType})');
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const EcranAccueil()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Erreur soumission vérification : $e');
      if (mounted) {
        setState(() => _enChargement = false);
        _afficherErreur('Connexion instable. Veuillez réessayer.');
      }
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _apercuFichier(File? fichier, String texte, IconData icone) {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: fichier == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 42, color: Colors.blueAccent),
                const SizedBox(height: 8),
                Text(texte, style: const TextStyle(color: Colors.grey)),
              ],
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(fichier, fit: BoxFit.cover),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification de fiabilité'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.verified_user_outlined,
                size: 64, color: Colors.blueAccent),
            const SizedBox(height: 16),
            const Text(
              'Vérification de fiabilité',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cette vérification garantit la fiabilité de la mise en relation et du suivi. Elle est obligatoire pour protéger les clients et les professionnels.',
              style: TextStyle(color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 28),
            const Text('1. Selfie obligatoire',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _enChargement ? null : _prendreSelfie,
              child: _apercuFichier(
                _selfie,
                'Prendre un selfie avec la caméra',
                Icons.camera_alt_outlined,
              ),
            ),
            const SizedBox(height: 24),
            const Text('2. Document justificatif obligatoire',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _typeDocument,
              decoration: const InputDecoration(
                labelText: 'Type de document',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'CNI', child: Text('CNI')),
                DropdownMenuItem(
                    value: 'carte_scolaire', child: Text('Carte scolaire')),
                DropdownMenuItem(
                    value: 'certificat', child: Text('Certificat')),
                DropdownMenuItem(value: 'autre', child: Text('Autre preuve')),
              ],
              onChanged: _enChargement
                  ? null
                  : (value) {
                      if (value != null) setState(() => _typeDocument = value);
                    },
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _enChargement ? null : _choisirDocument,
              child: _apercuFichier(
                _document,
                'Ajouter une pièce ou une preuve',
                Icons.upload_file_outlined,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _enChargement ? null : _soumettreVerification,
                icon: const Icon(Icons.send_rounded),
                label: _enChargement
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Soumettre pour vérification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Après l’envoi, vous pourrez utiliser normalement l’application pendant l’examen de votre dossier.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
