import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

// ══════════════════════════════════════════════════════
// BOUTON FLOTTANT
// ══════════════════════════════════════════════════════
class BoutonAssistantIA extends StatelessWidget {
  const BoutonAssistantIA({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const AssistantIASheet(),
      ),
      backgroundColor: const Color(0xFF1A237E),
      icon: const Icon(Icons.auto_awesome, color: Colors.white),
      label: const Text('Assistant IA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

// ══════════════════════════════════════════════════════
// ASSISTANT IA — Bottom Sheet
// ══════════════════════════════════════════════════════
class AssistantIASheet extends StatefulWidget {
  const AssistantIASheet({super.key});

  @override
  State<AssistantIASheet> createState() => _AssistantIASheetState();
}

class _AssistantIASheetState extends State<AssistantIASheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _enChargement = false;

  @override
  void initState() {
    super.initState();
    _messages.add({
      'role': 'assistant',
      'text': '👋 Bonjour ! Je suis votre assistant Service Pro CI.\n\nDécrivez votre problème et je vous trouve l\'artisan qu\'il vous faut.\n\nEx: "Mon robinet fuit" ou "Panne électrique dans le salon"',
    });
  }

  Future<void> _envoyerMessage() async {
    final texte = _controller.text.trim();
    if (texte.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': texte});
      _enChargement = true;
    });
    _controller.clear();
    _scrollerBas();

    try {
      final analyse = await _analyserAvecGemini(texte);
      final artisans = await _rechercherArtisans(analyse['metier'] ?? '');
      final reponse = _construireReponse(analyse, artisans);

      setState(() {
        _messages.add({'role': 'assistant', 'text': reponse});
        _enChargement = false;
      });

      if (artisans.isNotEmpty && mounted) {
        _proposerNavigation(analyse['metier'] ?? '', artisans);
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': '❌ Désolé, une erreur est survenue. Réessayez.',
        });
        _enChargement = false;
      });
    }
    _scrollerBas();
  }

  Future<Map<String, dynamic>> _analyserAvecGemini(String probleme) async {
    final response = await http.post(
      Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyDgh5fwAA43ziLPK0yHEIwv1kATEJHuazY',
      ),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'text': '''Tu es l\'assistant de Service Pro CI en Côte d\'Ivoire.
Analyse ce problème : "$probleme"
Réponds UNIQUEMENT en JSON valide, sans markdown :
{"metier":"plombier","urgence":"haute","resume":"résumé en 1 phrase","conseil":"conseil pratique"}
Métiers : plombier, électricien, menuisier, peintre, maçon, jardinier, climatiseur, serrurier
Si inconnu, mets "inconnu".'''
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': 200,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final texte = data['candidates'][0]['content']['parts'][0]['text'] as String;
      final jsonStr = texte.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(jsonStr);
    }
    throw Exception('Erreur API Gemini : ${response.statusCode}');
  }

  Future<List<Map<String, dynamic>>> _rechercherArtisans(String metier) async {
    if (metier == 'inconnu' || metier.isEmpty) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('artisans')
        .where('metier', isEqualTo: metier)
        .where('isDisponible', isEqualTo: true)
        .orderBy('note_moyenne', descending: true)
        .limit(3)
        .get();

    return snapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }

  String _construireReponse(
      Map<String, dynamic> analyse, List<Map<String, dynamic>> artisans) {
    final metier = analyse['metier'] ?? 'inconnu';
    final urgence = analyse['urgence'] ?? 'moyenne';
    final resume = analyse['resume'] ?? '';
    final conseil = analyse['conseil'] ?? '';

    String emoji = urgence == 'haute' ? '🚨' : urgence == 'moyenne' ? '⚠️' : '✅';
    String texte = '$emoji $resume\n\n';

    if (conseil.isNotEmpty) texte += '💡 Conseil : $conseil\n\n';

    if (metier == 'inconnu') {
      return texte + 'Je n\'ai pas pu identifier le type d\'artisan. Pouvez-vous préciser ?';
    }

    if (artisans.isEmpty) {
      return texte + '🔍 Aucun $metier disponible en ce moment.';
    }

    texte += '🎯 ${artisans.length} $metier(s) disponible(s) :\n\n';
    for (final a in artisans) {
      final note = (a['note_moyenne'] ?? 0.0).toStringAsFixed(1);
      final ville = a['ville'] ?? '';
      texte += '• ${a['nom']} — ⭐ $note — 📍 $ville\n';
    }
    return texte;
  }

  void _proposerNavigation(String metier, List<Map<String, dynamic>> artisans) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${artisans.length} artisan(s) trouvé(s)'),
        content: Text('Voir tous les $metier disponibles ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Non merci'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EcranListeArtisans(categorie: metier),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E)),
            child: const Text('Voir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _scrollerBas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, __) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Color(0xFF1A237E), size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Assistant IA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1A237E))),
                      Text('Décrivez votre problème',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_enChargement ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index == _messages.length) {
                    return const _BulleChargement();
                  }
                  final msg = _messages[index];
                  return _BulleMessage(
                    texte: msg['text']!,
                    estUtilisateur: msg['role'] == 'user',
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ex: Mon robinet fuit...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _envoyerMessage(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _enChargement ? null : _envoyerMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A237E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulle message ─────────────────────────────────────
class _BulleMessage extends StatelessWidget {
  final String texte;
  final bool estUtilisateur;
  const _BulleMessage({required this.texte, required this.estUtilisateur});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: estUtilisateur ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: estUtilisateur ? const Color(0xFF1A237E) : Colors.grey.shade100,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(estUtilisateur ? 16 : 4),
            bottomRight: Radius.circular(estUtilisateur ? 4 : 16),
          ),
        ),
        child: Text(
          texte,
          style: TextStyle(
            color: estUtilisateur ? Colors.white : Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

// ── Bulle chargement ──────────────────────────────────
class _BulleChargement extends StatelessWidget {
  const _BulleChargement();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF1A237E)),
            ),
            const SizedBox(width: 8),
            Text('Analyse en cours...',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}