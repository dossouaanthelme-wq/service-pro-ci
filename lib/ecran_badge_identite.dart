import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class EcranBadgeIdentite extends StatefulWidget {
  const EcranBadgeIdentite({super.key});

  @override
  State<EcranBadgeIdentite> createState() => _EcranBadgeIdentiteState();
}

class _EcranBadgeIdentiteState extends State<EcranBadgeIdentite> {
  final GlobalKey _badgeKey = GlobalKey();
  bool _enChargement = true;
  bool _partageEnCours = false;
  Map<String, dynamic> _userData = {};
  Map<String, dynamic> _artisanData = {};

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final artisanSnapshot = await FirebaseFirestore.instance
        .collection('artisans')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    setState(() {
      _userData = userSnapshot.data() ?? {};
      _artisanData = artisanSnapshot.data() ?? {};
      _enChargement = false;
    });
  }

  Future<void> _partagerBadge() async {
    if (_partageEnCours) return;
    setState(() => _partageEnCours = true);
    try {
      final boundary = _badgeKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Badge indisponible');
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Export impossible');
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/badge-service-pro.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Mon badge d’identité vérifiée Service Pro CI',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’exporter le badge : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _partageEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enChargement) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final identifiant = _userData['identifiantUnique']?.toString() ?? '';
    final nom = _userData['fullName'] ??
        '${_userData['prenom'] ?? ''} ${_userData['nom'] ?? ''}'.trim();
    final photo = _artisanData['photo_profil']?.toString().isNotEmpty == true
        ? _artisanData['photo_profil'].toString()
        : _userData['selfieUrl']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon badge vérifié'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            RepaintBoundary(
              key: _badgeKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.blueAccent, width: 2),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 10),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.verified, color: Colors.green, size: 42),
                    const SizedBox(height: 8),
                    const Text('SERVICE PRO CI',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    CircleAvatar(
                      radius: 54,
                      backgroundImage:
                          photo != null ? NetworkImage(photo) : null,
                      child: photo == null
                          ? const Icon(Icons.person, size: 54)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(nom.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(_artisanData['metier']?.toString() ?? 'Artisan'),
                    Text(_artisanData['ville']?.toString() ?? ''),
                    Text(_artisanData['telephone']?.toString() ?? ''),
                    const SizedBox(height: 16),
                    QrImageView(
                      data: identifiant,
                      size: 150,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Text(identifiant,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text('Identité vérifiée',
                        style: TextStyle(color: Colors.green)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: identifiant.isEmpty || _partageEnCours
                    ? null
                    : _partagerBadge,
                icon: const Icon(Icons.share),
                label: Text(_partageEnCours
                    ? 'Préparation...'
                    : 'Télécharger / Imprimer mon badge'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
