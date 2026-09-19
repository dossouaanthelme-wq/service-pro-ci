import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'main.dart';

class EcranModerationVerifications extends StatefulWidget {
  const EcranModerationVerifications({super.key});

  @override
  State<EcranModerationVerifications> createState() =>
      _EcranModerationVerificationsState();
}

class _EcranModerationVerificationsState
    extends State<EcranModerationVerifications>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool? _autorise;
  String? _traitementUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _verifierAcces();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _verifierAcces() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != serviceProAdminUid) {
      if (mounted) setState(() => _autorise = false);
      return;
    }
    final adminDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (mounted) {
      setState(() => _autorise = adminDoc.data()?['role'] == 'admin');
    }
  }

  String _genererIdentifiant(String role) {
    const caracteres = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final code = List.generate(
      6,
      (_) => caracteres[random.nextInt(caracteres.length)],
    ).join();
    return 'SPCI-${role == 'artisan' ? 'A' : 'C'}-$code';
  }

  Future<void> _valider(DocumentSnapshot document) async {
    final data = document.data() as Map<String, dynamic>;
    final role = data['role'] == 'artisan' ? 'artisan' : 'client';
    final identifiant = _genererIdentifiant(role);
    setState(() => _traitementUid = document.id);
    try {
      await document.reference.update({
        'statutVerification': 'valide',
        'identifiantUnique': identifiant,
        'dateValidation': FieldValue.serverTimestamp(),
        'qrCodeData': {
          'type': 'verification_identite',
          'uid': document.id,
          'identifiantUnique': identifiant,
          'role': role,
        },
        'motifRejet': null,
      });
        final artisanSnapshot = role == 'artisan'
          ? await FirebaseFirestore.instance
            .collection('artisans')
            .doc(document.id)
            .get()
          : null;
        final artisanData = artisanSnapshot?.data() ?? <String, dynamic>{};
        final nomComplet = data['fullName'] ??
          '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
        await FirebaseFirestore.instance
          .collection('identifiants_verifies')
          .doc(identifiant)
          .set({
        'uid': document.id,
        'role': role,
        'identifiantUnique': identifiant,
        'nomComplet': nomComplet,
        'photoUrl': role == 'artisan'
          ? artisanData['photo_profil']
          : data['photo_profil'],
        'metier': artisanData['metier'] ?? '',
        'ville': artisanData['ville'] ?? '',
        'dateValidation': FieldValue.serverTimestamp(),
        });
      _afficherMessage('Demande validée : $identifiant');
    } catch (e) {
      _afficherMessage('Erreur lors de la validation : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _traitementUid = null);
    }
  }

  Future<void> _rejeter(DocumentSnapshot document) async {
    final data = document.data() as Map<String, dynamic>;
    final motifController = TextEditingController();
    final motif = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter la vérification'),
        content: TextField(
          controller: motifController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Motif du rejet',
            hintText: 'Expliquez les documents à corriger.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final motif = motifController.text.trim();
              if (motif.isNotEmpty) Navigator.pop(context, motif);
            },
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );
    motifController.dispose();
    if (motif == null) return;

    setState(() => _traitementUid = document.id);
    try {
      final ancienIdentifiant = data['identifiantUnique']?.toString();
      if (ancienIdentifiant != null && ancienIdentifiant.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('identifiants_verifies')
            .doc(ancienIdentifiant)
            .delete();
      }
      await document.reference.update({
        'statutVerification': 'rejete',
        'motifRejet': motif,
        'dateValidation': null,
      });
      _afficherMessage('Demande rejetée.');
    } catch (e) {
      _afficherMessage('Erreur lors du rejet : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _traitementUid = null);
    }
  }

  void _afficherMessage(String message, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: erreur ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _demandeCard(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;
    final nom = data['fullName'] ??
        '${data['prenom'] ?? ''} ${data['nom'] ?? ''}'.trim();
    final role = data['role'] == 'artisan' ? 'Artisan' : 'Client';
    final telephone = data['telephone'] ?? 'Téléphone non renseigné';
    final selfieUrl = data['selfieUrl']?.toString() ?? '';
    final documentUrl = data['documentUrl']?.toString() ?? '';
    final enTraitement = _traitementUid == document.id;

    Widget image(String url, String label) {
      return Expanded(
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            AspectRatio(
              aspectRatio: 1,
              child: url.isEmpty
                  ? const ColoredBox(
                      color: Colors.black12,
                      child: Icon(Icons.image_not_supported),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Colors.black12,
                        child: Icon(Icons.broken_image),
                      ),
                    ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(nom.toString().isEmpty ? 'Utilisateur sans nom' : nom.toString(),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('$role • $telephone'),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [image(selfieUrl, 'Selfie'), const SizedBox(width: 10), image(documentUrl, 'Document')],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: enTraitement ? null : () => _valider(document),
                    icon: const Icon(Icons.check),
                    label: const Text('Valider'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enTraitement ? null : () => _rejeter(document),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Rejeter'),
                  ),
                ),
              ],
            ),
            if (enTraitement)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _liste(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('statutVerification', isEqualTo: 'en_attente')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Accès refusé ou erreur : ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final demandes = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['role'] == role);
        }).toList();
        if (demandes.isEmpty) {
          return Center(child: Text('Aucune demande ${role == 'artisan' ? 'artisan' : 'client'} en attente.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: demandes.length,
          itemBuilder: (context, index) => _demandeCard(demandes[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_autorise == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_autorise != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Accès refusé')),
        body: const Center(
          child: Text('Cet espace est réservé à l’administrateur.'),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modération des vérifications'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Artisans'), Tab(text: 'Clients')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_liste('artisan'), _liste('client')],
      ),
    );
  }
}
