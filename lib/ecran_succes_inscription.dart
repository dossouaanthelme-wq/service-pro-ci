import 'package:flutter/material.dart';
import 'main.dart';

// ==========================================
// ÉCRAN : SUCCÈS DE L'INSCRIPTION ARTISAN
// Affiché juste après la publication de la fiche.
// Le retour arrière est bloqué : l'artisan ne peut
// plus revenir sur l'écran d'accueil / d'inscription.
// ==========================================
class EcranSuccesInscription extends StatefulWidget {
  final String prenom;
  final String metier;

  const EcranSuccesInscription({
    super.key,
    required this.prenom,
    required this.metier,
  });

  @override
  State<EcranSuccesInscription> createState() => _EcranSuccesInscriptionState();
}

class _EcranSuccesInscriptionState extends State<EcranSuccesInscription>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _haloAnim;
  late Animation<double> _checkAnim;
  late Animation<double> _titreFade;
  late Animation<Offset> _titreSlide;
  late Animation<double> _cartesFade;
  late Animation<Offset> _cartesSlide;
  late Animation<double> _boutonFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _haloAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _checkAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.10, 0.55, curve: Curves.elasticOut),
      ),
    );
    _titreFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.70, curve: Curves.easeIn),
    );
    _titreSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.70, curve: Curves.easeOut),
      ),
    );
    _cartesFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.62, 0.88, curve: Curves.easeIn),
    );
    _cartesSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.62, 0.88, curve: Curves.easeOut),
      ),
    );
    _boutonFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.82, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Vers le profil, en vidant toute la pile de navigation ──
  void _allerAuProfil() {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const EcranProfil(estNouveau: true),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ canPop: false → le bouton retour Android ne fait plus rien
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1565C0),
                Color(0xFF1E88E5),
                Color(0xFF42A5F5),
              ],
            ),
          ),
          child: Stack(
            children: [
              // ── Cercles décoratifs ──────────────────────
              Positioned(
                top: -70,
                right: -70,
                child: _cercleDeco(230),
              ),
              Positioned(
                bottom: -90,
                left: -60,
                child: _cercleDeco(280),
              ),
              Positioned(
                top: 140,
                left: -50,
                child: _cercleDeco(130),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // ── Check animé ─────────────────────
                      _buildCheck(),

                      const SizedBox(height: 34),

                      // ── Titre ───────────────────────────
                      FadeTransition(
                        opacity: _titreFade,
                        child: SlideTransition(
                          position: _titreSlide,
                          child: Column(
                            children: [
                              Text(
                                widget.prenom.isEmpty
                                    ? 'Félicitations ! 🎉'
                                    : 'Félicitations ${widget.prenom} ! 🎉',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Votre fiche ${widget.metier.toLowerCase()} est\nmaintenant en ligne',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: Colors.white.withValues(alpha: 0.88),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 34),

                      // ── Cartes d'information ────────────
                      FadeTransition(
                        opacity: _cartesFade,
                        child: SlideTransition(
                          position: _cartesSlide,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Column(
                              children: [
                                _ligneInfo(
                                  Icons.visibility_rounded,
                                  'Visible par tous les clients',
                                  'Vous apparaissez dans la catégorie ${widget.metier}',
                                ),
                                _separateur(),
                                _ligneInfo(
                                  Icons.star_rounded,
                                  'Note de départ : 5,0 ⭐',
                                  'Vos premiers avis feront la différence',
                                ),
                                _separateur(),
                                _ligneInfo(
                                  Icons.phone_in_talk_rounded,
                                  'Contact direct',
                                  'Les clients vous appellent en un clic',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // ── Bouton ──────────────────────────
                      FadeTransition(
                        opacity: _boutonFade,
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _allerAuProfil,
                                icon: const Icon(Icons.arrow_forward_rounded),
                                label: const Text(
                                  'Voir mon profil',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF1565C0),
                                  elevation: 6,
                                  shadowColor: Colors.black26,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Complétez votre profil pour attirer\nplus de clients',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Check animé (halo + icône) ────────────────────────
  Widget _buildCheck() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo externe
          ScaleTransition(
            scale: _haloAnim,
            child: FadeTransition(
              opacity: _haloAnim,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          // Halo interne
          ScaleTransition(
            scale: _haloAnim,
            child: Container(
              width: 122,
              height: 122,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
          ),
          // Pastille + check
          ScaleTransition(
            scale: _checkAnim,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 54,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cercleDeco(double taille) {
    return Container(
      width: taille,
      height: taille,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.07),
      ),
    );
  }

  Widget _separateur() => Divider(
        height: 1,
        color: Colors.white.withValues(alpha: 0.16),
      );

  Widget _ligneInfo(IconData icone, String titre, String sousTitre) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: Icon(icone, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sousTitre,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
