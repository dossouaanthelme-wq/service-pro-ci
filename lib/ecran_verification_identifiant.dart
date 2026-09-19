import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class EcranVerificationIdentifiant extends StatefulWidget {
  final String roleAutorise;

  const EcranVerificationIdentifiant({
    super.key,
    required this.roleAutorise,
  });

  @override
  State<EcranVerificationIdentifiant> createState() =>
      _EcranVerificationIdentifiantState();
}

class _EcranVerificationIdentifiantState
    extends State<EcranVerificationIdentifiant> {
  final _identifiantController = TextEditingController();
  Map<String, dynamic>? _resultat;
  bool _enChargement = false;
  bool _accesAutorise = false;

  @override
  void initState() {
    super.initState();
    _verifierRole();
  }

  @override
  void dispose() {
    _identifiantController.dispose();
    super.dispose();
  }

  Future<void> _verifierRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!mounted) return;
    setState(() => _accesAutorise = snapshot.data()?['role'] == widget.roleAutorise);
  }

  Future<void> _rechercher([String? valeur]) async {
    final identifiant = (valeur ?? _identifiantController.text).trim();
    if (identifiant.isEmpty) {
      _afficherErreur('Saisissez un identifiant unique.');
      return;
    }
    setState(() {
      _enChargement = true;
      _resultat = null;
    });
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('identifiants_verifies')
          .doc(identifiant)
          .get();
      if (!mounted) return;
      final data = snapshot.data();
      final roleRecherche = widget.roleAutorise == 'artisan' ? 'client' : 'artisan';
      setState(() {
        _resultat = snapshot.exists && data?['role'] == roleRecherche
            ? data
            : {};
        _enChargement = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _enChargement = false);
        _afficherErreur('Recherche impossible : $e');
      }
    }
  }

  Future<void> _scanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ScannerIdentifiant(onDetected: (value) {
          Navigator.pop(context);
          _identifiantController.text = value;
          _rechercher(value);
        }),
      ),
    );
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _afficherResultat() {
    if (_resultat == null) return const SizedBox.shrink();
    if (_resultat!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Text('Identifiant non reconnu ou non vérifié',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 16)),
      );
    }
    final data = _resultat!;
    final photo = data['photoUrl']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty ? const Icon(Icons.person, size: 48) : null,
            ),
            const SizedBox(height: 12),
            Text(data['nomComplet']?.toString() ?? 'Utilisateur vérifié',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if ((data['metier']?.toString() ?? '').isNotEmpty)
              Text(data['metier'].toString()),
            if ((data['ville']?.toString() ?? '').isNotEmpty)
              Text(data['ville'].toString()),
            const SizedBox(height: 12),
            const Chip(
              avatar: Icon(Icons.verified, color: Colors.white),
              label: Text('Identité vérifiée', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
            ),
            const SizedBox(height: 8),
            Text('Identifiant : ${data['identifiantUnique']}'),
            if (data['dateValidation'] is Timestamp)
              Text('Validée le ${_formatDate((data['dateValidation'] as Timestamp).toDate())}'),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  @override
  Widget build(BuildContext context) {
    if (!_accesAutorise) {
      return const Scaffold(body: Center(child: Text('Accès non autorisé.')));
    }
    final estArtisan = widget.roleAutorise == 'artisan';
    return Scaffold(
      appBar: AppBar(
        title: Text(estArtisan ? 'Vérifier un client' : 'Vérifier un artisan'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.qr_code_scanner, size: 72, color: Colors.blueAccent),
            const SizedBox(height: 12),
            Text(
              estArtisan
                  ? 'Scannez ou saisissez l’identifiant du client.'
                  : 'Scannez ou saisissez l’identifiant de l’artisan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _identifiantController,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Identifiant unique',
                hintText: 'SPCI-A-XXXXXX ou SPCI-C-XXXXXX',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanner,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scanner un QR code'),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _enChargement ? null : () => _rechercher(),
                  child: const Text('Vérifier'),
                ),
              ],
            ),
            if (_enChargement) const Padding(
              padding: EdgeInsets.only(top: 24),
              child: CircularProgressIndicator(),
            ),
            _afficherResultat(),
          ],
        ),
      ),
    );
  }
}

class _ScannerIdentifiant extends StatelessWidget {
  final ValueChanged<String> onDetected;
  const _ScannerIdentifiant({required this.onDetected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un QR code')),
      body: MobileScanner(
        onDetect: (capture) {
          for (final barcode in capture.barcodes) {
            final value = barcode.rawValue;
            if (value != null && value.isNotEmpty) {
              onDetected(value);
              return;
            }
          }
        },
      ),
    );
  }
}
