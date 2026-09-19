import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'ecran_badge_identite.dart';
import 'main.dart';

class EcranVerificationArtisan extends StatefulWidget {
  const EcranVerificationArtisan({super.key});

  @override
  State<EcranVerificationArtisan> createState() =>
      _EcranVerificationArtisanState();
}

class _EcranVerificationArtisanState extends State<EcranVerificationArtisan> {
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
    if (image != null && mounted) setState(() => _selfie = File(image.path));
  }

  Future<void> _choisirDocument() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (image != null && mounted) setState(() => _document = File(image.path));
  }

  Future<String> _uploader(String uid, String nom, File fichier) async {
    final reference = FirebaseStorage.instance
        .ref()
        .child('verifications_artisans')
        .child(uid)
        .child('$nom.jpg');
    debugPrint('KYC artisan Storage upload start path=${reference.fullPath}');
    try {
      await reference.putFile(fichier);
      final url = await reference.getDownloadURL();
      debugPrint('KYC artisan Storage upload success path=${reference.fullPath} url=$url');
      return url;
    } on FirebaseException catch (e) {
      debugPrint(
        'KYC artisan Storage upload error path=${reference.fullPath} '
        'code=${e.code} message=${e.message} details=${e.toString()}',
      );
      rethrow;
    }
  }

  Future<void> _soumettre() async {
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
      final selfieUrl = await _uploader(user.uid, 'selfie', _selfie!);
      final documentUrl = await _uploader(user.uid, 'document', _document!);
      final payload = <String, dynamic>{
        'statutVerification': 'en_attente',
        'selfieUrl': selfieUrl,
        'documentUrl': documentUrl,
        'typeDocument': _typeDocument,
        'dateSoumission': FieldValue.serverTimestamp(),
      };
      debugPrint('KYC artisan uid=${user.uid} payload:');
      payload.forEach((key, value) {
        debugPrint('  $key = $value (type=${value.runtimeType})');
      });
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const EcranProfil()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _enChargement = false);
        _afficherErreur('Impossible de soumettre la vérification : $e');
      }
    }
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _apercu(File? fichier, String texte, IconData icone) {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: fichier == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, size: 40, color: Colors.blueAccent),
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

  Widget _formulaire() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vérifier mon identité',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Une identité vérifiée renforce la confiance des clients. Préparez un selfie et une pièce d’identité, carte scolaire, certificat professionnel ou RCCM.',
          style: TextStyle(color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 24),
        const Text('Selfie obligatoire',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _enChargement ? null : _prendreSelfie,
          child: _apercu(_selfie, 'Prendre un selfie', Icons.camera_alt),
        ),
        const SizedBox(height: 20),
        const Text('Document justificatif obligatoire',
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
                value: 'certificat', child: Text('Certificat professionnel')),
            DropdownMenuItem(value: 'RCCM', child: Text('RCCM')),
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
          child: _apercu(
              _document, 'Ajouter le document', Icons.upload_file_outlined),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _enChargement ? null : _soumettre,
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
      ],
    );
  }

  Widget _contenu(Map<String, dynamic> data) {
    final statut = data['statutVerification']?.toString() ?? 'non_soumis';

    if (statut == 'en_attente') {
      return const Center(
        child: Column(
          children: [
            Icon(Icons.hourglass_top, size: 72, color: Colors.orange),
            SizedBox(height: 16),
            Text('Vérification en cours',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Votre dossier est en cours d’examen par l’administrateur.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (statut == 'valide') {
      final identifiant = data['identifiantUnique']?.toString();
      return Center(
        child: Column(
          children: [
            const Icon(Icons.verified, size: 76, color: Colors.green),
            const SizedBox(height: 16),
            const Text('Identité vérifiée',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              identifiant == null || identifiant.isEmpty
                  ? 'Identifiant unique en cours de génération.'
                  : 'Identifiant unique : $identifiant',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: identifiant == null || identifiant.isEmpty
                  ? null
                  : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EcranBadgeIdentite(),
                        ),
                      ),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Voir ma carte d’identité'),
            ),
          ],
        ),
      );
    }

    if (statut == 'rejete') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 12),
          const Text('Vérification rejetée',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Motif : ${data['motifRejet'] ?? 'Motif non précisé.'}',
              style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 24),
          _formulaire(),
        ],
      );
    }

    return _formulaire();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Utilisateur non connecté')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vérification d’identité'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _contenu(snapshot.data!.data() ?? {}),
          );
        },
      ),
    );
  }
}
