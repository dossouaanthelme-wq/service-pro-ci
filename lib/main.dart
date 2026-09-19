import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'auth_service.dart';
import 'verify_email_page.dart';
import 'package:path_provider/path_provider.dart';
import 'ecran_auth_telephone.dart';
import 'ecran_verification_client.dart';
import 'ecran_verification_artisan.dart';
import 'ecran_moderation_verifications.dart';
import 'ecran_badge_identite.dart';
import 'ecran_verification_identifiant.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';

const String serviceProAdminUid = 'rZASbWUSzCXrFOs8GqZd7YTD6A53';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'service_pro_channel',
        'Service Pro Notifications',
        channelDescription: 'Notifications for Service Pro CI',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: false,
      );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    0,
    message.notification?.title ?? 'Notification',
    message.notification?.body ?? 'Vous avez une nouvelle notification',
    platformChannelSpecifics,
  );
}

Future<void> _initNotificationsBackground() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ── Permissions ──────────────────────────────────
  await messaging.requestPermission(alert: true, badge: true, sound: true);

  // ── Créer le canal Android AVEC son ──────────────
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'service_pro_channel', // id
    'Service Pro Notifications', // nom
    description: 'Notifications pour Service Pro CI',
    importance: Importance.high, // ✅ HIGH = son + vibration
    playSound: true, // ✅ Son activé
    enableVibration: true, // ✅ Vibration activée
    enableLights: true, // ✅ Lumière LED activée
  );

  // Enregistrer le canal sur Android
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  // ── Initialisation ────────────────────────────────
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (details) {
      // Tu peux gérer le clic sur la notification ici
    },
  );

  // ── Sauvegarde token FCM ──────────────────────────
  String? token = await messaging.getToken();
  if (token != null) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final artisanDoc = await FirebaseFirestore.instance
          .collection('artisans')
          .where('uid', isEqualTo: user.uid)
          .get();
      if (artisanDoc.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('artisans')
            .doc(artisanDoc.docs.first.id)
            .update({'fcmToken': token});
      }
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
      }, SetOptions(merge: true));
    }
  }

  // ── Refresh token ─────────────────────────────────
  messaging.onTokenRefresh.listen((newToken) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final artisanDoc = await FirebaseFirestore.instance
          .collection('artisans')
          .where('uid', isEqualTo: user.uid)
          .get();
      if (artisanDoc.docs.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('artisans')
            .doc(artisanDoc.docs.first.id)
            .update({'fcmToken': newToken});
      }
    }
  });

  // ── Notifications au premier plan (foreground) ────
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        // ✅ Utilise le canal avec son défini plus haut
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high, // ✅ Priorité haute
            playSound: true, // ✅ Son
            enableVibration: true, // ✅ Vibration
            enableLights: true, // ✅ LED
            color: const Color(0xFF1565C0), // ✅ Couleur bleue
            largeIcon: const DrawableResourceAndroidBitmap(
              '@mipmap/ic_launcher', // ✅ Icône large
            ),
          ),
        ),
      );
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

await FirebaseAppCheck.instance.activate(
  androidProvider: kDebugMode
      ? AndroidProvider.debug
      : AndroidProvider.playIntegrity,
);


  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const ServiceProApp());
}

class ServiceProApp extends StatefulWidget {
  const ServiceProApp({super.key});

  @override
  State<ServiceProApp> createState() => _ServiceProAppState();
}

class EcranSplash extends StatefulWidget {
  const EcranSplash({super.key});

  @override
  State<EcranSplash> createState() => _EcranSplashState();
}

class _EcranSplashState extends State<EcranSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _textFadeAnim;
  late Animation<Offset> _textSlideAnim;
  late Animation<double> _pointsAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _textFadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.7, curve: Curves.easeIn),
    );
    _textSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.7, curve: Curves.easeOut),
      ),
    );
    _pointsAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1565C0),
              const Color(0xFF1E88E5),
              Colors.blue.shade300,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -50,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              top: 120,
              left: -40,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(18),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  FadeTransition(
                    opacity: _textFadeAnim,
                    child: SlideTransition(
                      position: _textSlideAnim,
                      child: Column(
                        children: [
                          const Text(
                            'Service Pro CI',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Votre artisan de confiance à Abidjan',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.85),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                  FadeTransition(
                    opacity: _pointsAnim,
                    child: _PointsChargement(),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _textFadeAnim,
                child: Text(
                  'v1.0.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceProAppState extends State<ServiceProApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      _verifierSessionEtNaviguer();
    });
  }

  // ✅ NOUVELLE FONCTION : Vérification sécurisée au démarrage
  Future<void> _verifierSessionEtNaviguer() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Pas connecté → accueil normal
      _naviguerVers(const EcranAccueil());
      return;
    }

    // ✅ Recharger le statut Firebase pour avoir les infos à jour
    await user.reload();
    final userActuel = FirebaseAuth.instance.currentUser;

    if (userActuel == null) {
      _naviguerVers(const EcranAccueil());
      return;
    }

    // ✅ Vérifier si connecté via téléphone (pas besoin de vérification email)
    final estConnexionTelephone = userActuel.providerData.any(
      (p) => p.providerId == 'phone',
    );

    if (estConnexionTelephone) {
      // Connexion téléphone → accueil direct
      await _naviguerClientOuAccueil(userActuel);
      return;
    }

    // ✅ Connexion email → vérifier si email vérifié
    if (!userActuel.emailVerified) {
            debugPrint(
        'Déconnexion au démarrage : email non vérifié, '
        'providers=${userActuel.providerData.map((p) => p.providerId).toList()}, '
        'emailVerified=${userActuel.emailVerified}, '
        'estConnexionTelephone=$estConnexionTelephone',
      );
      // Email non vérifié → déconnecter et rediriger
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Veuillez vérifier votre email pour continuer.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 4),
          ),
        );
      }
      _naviguerVers(const EcranAccueil());
      return;
    }

    // ✅ Email vérifié → accueil normal
    await _naviguerClientOuAccueil(userActuel);
  }

  Future<void> _naviguerClientOuAccueil(User user) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data();
    final estClient = data?['role'] != 'artisan';
    final statut = data?['statutVerification'];

    if (estClient && statut == 'non_soumis') {
      _naviguerVers(const EcranVerificationClient());
    } else {
      _naviguerVers(const EcranAccueil());
    }
  }

  void _naviguerVers(Widget ecran) {
    if (!mounted) return;
    _navigatorKey.currentState?.pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ecran,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Service Pro CI',
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      home: const EcranSplash(),
    );
  }
}

// ==========================================
// WIDGET : POINTS DE CHARGEMENT ANIMÉS
// ==========================================
class _PointsChargement extends StatefulWidget {
  @override
  State<_PointsChargement> createState() => _PointsChargementState();
}

class _PointsChargementState extends State<_PointsChargement>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _anims = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < 3; i++) {
      final controller = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      final anim = Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
      _controllers.add(controller);
      _anims.add(anim);

      // Décalage entre chaque point
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: FadeTransition(
            opacity: _anims[i],
            child: ScaleTransition(
              scale: _anims[i],
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ==========================================
// ÉCRAN 1 : L'ACCUEIL — VERSION REDESIGNÉE
// ==========================================
class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key});

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  String? _prenom;
  String? _role;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    FirebaseAuth.instance.authStateChanges().listen((_) {
      if (mounted) _chargerInfosUtilisateur();
    });

    _chargerInfosUtilisateur();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _chargerInfosUtilisateur() async {
    setState(() => _chargement = true);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        _prenom = null;
        _role = null;
        _chargement = false;
      });
      _animController.forward(from: 0);
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = userDoc.data();
    final role = data?['role'] == 'artisan' ? 'artisan' : 'client';
    setState(() {
      _prenom = data?['prenom'] ?? data?['nom'] ??
          (role == 'artisan' ? 'Artisan' : 'Client');
      _role = role;
      _chargement = false;
    });

    _animController.forward(from: 0);
  }

  String get _messageAccueil {
    final heure = DateTime.now().hour;
    final salut = heure < 12
        ? 'Bonjour'
        : heure < 18
        ? 'Bon après-midi'
        : 'Bonsoir';
    if (_prenom != null) return '$salut, $_prenom 👋';
    return '$salut 👋';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final estConnecte = user != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(user),
      drawer: const MenuLateral(),
      // ✅ AJOUTE ICI (ligne 624)
      // floatingActionButton: const BoutonAssistantIA(),
      body: _chargement
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildHero(estConnecte),
                      _buildContenu(estConnecte),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  // ── APP BAR ──────────────────────────────────────────
  AppBar _buildAppBar(User? user) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.blueAccent, size: 32),
      actions: [
        StreamBuilder<QuerySnapshot>(
          stream: user != null
              ? FirebaseFirestore.instance
                    .collection('notifications')
                    .where('targetUserId', isEqualTo: user.uid)
                    .where('isRead', isEqualTo: false)
                    .snapshots()
              : const Stream.empty(),
          builder: (context, personalSnap) {
            final personal = (user != null && personalSnap.hasData)
                ? personalSnap.data!.docs.length
                : 0;
            return StreamBuilder<QuerySnapshot>(
              stream: user != null
                  ? FirebaseFirestore.instance
                        .collection('notifications')
                        .where('isGlobal', isEqualTo: true)
                        .where('isRead', isEqualTo: false)
                        .snapshots()
                  : const Stream.empty(),
              builder: (context, globalSnap) {
                final global = (user != null && globalSnap.hasData)
                    ? globalSnap.data!.docs.length
                    : 0;
                final total = personal + global;
                return IconButton(
                  icon: Badge(
                    label: total > 0 ? Text(total.toString()) : null,
                    isLabelVisible: total > 0,
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.blueAccent,
                    ),
                  ),
                  onPressed: () {
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Connectez-vous pour voir vos notifications',
                          ),
                          backgroundColor: Colors.blueAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsPage(),
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  // ── HERO IMAGE ───────────────────────────────────────
  Widget _buildHero(bool estConnecte) {
    return Stack(
      children: [
        // Image
        Container(
          width: double.infinity,
          height: 260,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: Image.asset('assets/hero.png', fit: BoxFit.cover),
          ),
        ),

        // Dégradé bas
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.55)],
                ),
              ),
            ),
          ),
        ),

        // Texte sur l'image
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _messageAccueil,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(blurRadius: 6, color: Colors.black45)],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                estConnecte
                    ? _role == 'artisan'
                          ? 'Gérez vos missions et votre profil ✨'
                          : 'Trouvez l\'artisan qu\'il vous faut 🔧'
                    : 'Votre artisan de confiance à Abidjan',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── CONTENU PRINCIPAL ────────────────────────────────
  Widget _buildContenu(bool estConnecte) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
      child: Column(
        children: [
          // Titre
          const Text(
            'Trouvez un artisan fiable',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Rapide • Sécurisé • Pro • À Abidjan',
            style: TextStyle(fontSize: 15, color: Colors.grey),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Bouton CLIENT
          // Bouton CLIENT — titre change selon l'état de connexion
          _BoutonChoix(
            icone: Icons.search_rounded,
            titre: estConnecte
                ? 'Trouver un pro chap chap'
                : 'Je suis un CLIENT',
            description: estConnecte
                ? 'Trouvez un artisan rapidement'
                : 'Trouvez un artisan près de chez vous',
            couleurFond: const Color(0xFF1565C0),
            couleurTexte: Colors.white,
            onTap: () {
  if (FirebaseAuth.instance.currentUser == null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EcranAuthentification(),
      ),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const EcranCategories()),
  );
},
          ),

          const SizedBox(height: 16),

          // Bouton ARTISAN — visible seulement si NON connecté
          if (!estConnecte) ...[
            const SizedBox(height: 16),
            _BoutonChoix(
              icone: Icons.handyman_rounded,
              titre: 'Je suis un ARTISAN',
              description: 'Inscrivez-vous et proposez vos services',
              couleurFond: Colors.white,
              couleurTexte: const Color(0xFF1565C0),
              bordure: const BorderSide(color: Color(0xFF1565C0), width: 2),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Veuillez vous connecter pour proposer vos services.',
                    ),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EcranAuthentification(),
                  ),
                );
              },
            ),
          ],

          // Badge connecté
          if (estConnecte) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: Colors.green.shade600,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Connecté en tant que ${_role == 'artisan' ? 'Artisan' : 'Client'}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==========================================
// WIDGET : BOUTON CHOIX CLIENT / ARTISAN
// ==========================================
class _BoutonChoix extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String description;
  final Color couleurFond;
  final Color couleurTexte;
  final BorderSide? bordure;
  final VoidCallback onTap;

  const _BoutonChoix({
    required this.icone,
    required this.titre,
    required this.description,
    required this.couleurFond,
    required this.couleurTexte,
    required this.onTap,
    this.bordure,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: couleurFond,
      elevation: bordure == null ? 4 : 0,
      shadowColor: Colors.blueAccent.withOpacity(0.3),
      shape: bordure != null
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: bordure!,
            )
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: couleurTexte.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icone, color: couleurTexte, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: couleurTexte,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: couleurTexte.withOpacity(0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: couleurTexte.withOpacity(0.6),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ÉCRAN 2 : LES CATÉGORIES
// ==========================================
class EcranCategories extends StatelessWidget {
  const EcranCategories({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Que recherchez-vous ?'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
          children: [
            _creerCarteMetier(context, Icons.grid_on, 'Carreleur'),
            _creerCarteMetier(
              context,
              Icons.computer,
              'Technicien Informatique',
            ),
            _creerCarteMetier(
              context,
              Icons.bug_report,
              'Dératiseur / Désinsectiseur',
            ),
            _creerCarteMetier(
              context,
              Icons.electrical_services,
              'Électricien',
            ),
            _creerCarteMetier(context, Icons.ac_unit, 'Froid / Climatisation'),
            _creerCarteMetier(context, Icons.yard, 'Jardinier'),
            _creerCarteMetier(
              context,
              Icons.settings_input_antenna,
              'Antenniste',
            ),
            _creerCarteMetier(context, Icons.handyman, 'Maçonnerie'),
            _creerCarteMetier(context, Icons.build, 'Mécanicien (Auto / Moto)'),
            _creerCarteMetier(
              context,
              Icons.kitchen,
              'Réparateur d\'électroménager',
            ),
            _creerCarteMetier(context, Icons.carpenter, 'Menuisier'),
            _creerCarteMetier(context, Icons.format_paint, 'Peintre'),
            _creerCarteMetier(context, Icons.plumbing, 'Plombier'),
            _creerCarteMetier(context, Icons.hardware, 'Soudeur / Métallique'),
          ],
        ),
      ),
    );
  }

  Widget _creerCarteMetier(BuildContext context, IconData icone, String titre) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EcranListeArtisans(categorie: titre),
          ),
        ),
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 50, color: Colors.blueAccent),
            const SizedBox(height: 10),
            Text(
              titre,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ÉCRAN 3 : LISTE ARTISANS
// ==========================================
// ==========================================
// ÉCRAN : LISTE DES ARTISANS — VERSION 2.0
// ==========================================
class EcranListeArtisans extends StatefulWidget {
  final String categorie;
  const EcranListeArtisans({super.key, required this.categorie});

  @override
  State<EcranListeArtisans> createState() => _EcranListeArtisansState();
}

class _EcranListeArtisansState extends State<EcranListeArtisans> {
  String _recherche = '';
  String? _villeSelectionnee; // null = toutes les villes
  String _filtreDispo = 'tous'; // 'tous' | 'enligne' | 'disponible'

  Future<void> _lancerAppel(String numero) async {
    final Uri url = Uri(scheme: 'tel', path: numero);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  // Extrait toutes les villes uniques depuis la liste d'artisans
  List<String> _extraireVilles(List<QueryDocumentSnapshot> docs) {
    final villes = docs
        .map((d) => ((d.data() as Map)['ville'] ?? '').toString().trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList();
    villes.sort();
    return villes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          widget.categorie,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(62),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Chercher un artisan ou une ville...',
                prefixIcon: const Icon(Icons.search, color: Colors.blueAccent),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _recherche = v.toLowerCase()),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('artisans')
            .where('metier', isEqualTo: widget.categorie)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const EcranVide(
              message: 'Aucun artisan dans cette catégorie pour le moment.',
            );
          }

          final tousArtisans = snapshot.data!.docs;
          final villes = _extraireVilles(tousArtisans);

          // ── Filtrage ──────────────────────────────────
          var artisans = tousArtisans.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ville = (data['ville'] ?? '').toString().toLowerCase();
            final nom = (data['nom'] ?? '').toString().toLowerCase();
            final isOnline = data['isOnline'] == true;
            final isDisponible = data['isDisponible'] == true;

            // Filtre texte (recherche)
            final matchRecherche =
                ville.contains(_recherche) || nom.contains(_recherche);

            // Filtre ville sélectionnée
            final matchVille =
                _villeSelectionnee == null ||
                ville == _villeSelectionnee!.toLowerCase();

            // Filtre disponibilité
            final matchDispo =
                _filtreDispo == 'tous' ||
                (_filtreDispo == 'enligne' && isOnline) ||
                (_filtreDispo == 'disponible' && isDisponible);

            return matchRecherche && matchVille && matchDispo;
          }).toList();

          // ── Tri : Premium → En ligne → Disponible → Reste
          artisans.sort((a, b) {
            final da = a.data() as Map<String, dynamic>;
            final db = b.data() as Map<String, dynamic>;
            int score(Map d) =>
                (d['isPremium'] == true ? 4 : 0) +
                (d['isOnline'] == true ? 2 : 0) +
                (d['isDisponible'] == true ? 1 : 0);
            return score(db).compareTo(score(da));
          });

          return Column(
            children: [
              // ── Barre filtres ──────────────────────────
              _BarreFiltres(
                villes: villes,
                villeSelectionnee: _villeSelectionnee,
                filtreDispo: _filtreDispo,
                onVilleChange: (v) => setState(() => _villeSelectionnee = v),
                onDispoChange: (v) => setState(() => _filtreDispo = v),
              ),

              // ── Compteur résultats ─────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Text(
                      '${artisans.length} artisan${artisans.length > 1 ? 's' : ''} trouvé${artisans.length > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // ── Liste ─────────────────────────────────
              Expanded(
                child: artisans.isEmpty
                    ? const EcranVide(
                        message: 'Aucun résultat pour cette recherche.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                        itemCount: artisans.length,
                        itemBuilder: (context, index) {
                          final doc = artisans[index];
                          final artisan = doc.data() as Map<String, dynamic>;
                          return _CarteArtisan(
                            artisan: artisan,
                            docId: doc.id,
                            onAppel: () =>
                                _lancerAppel(artisan['telephone'] ?? ''),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// WIDGET : BARRE DE FILTRES
// ==========================================
class _BarreFiltres extends StatelessWidget {
  final List<String> villes;
  final String? villeSelectionnee;
  final String filtreDispo;
  final ValueChanged<String?> onVilleChange;
  final ValueChanged<String> onDispoChange;

  const _BarreFiltres({
    required this.villes,
    required this.villeSelectionnee,
    required this.filtreDispo,
    required this.onVilleChange,
    required this.onDispoChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          // ── Filtre VILLE (dropdown) ──────────────────
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFFF0F4FF),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: villeSelectionnee,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.blueAccent,
                  ),
                  hint: const Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.blueAccent,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Toutes les villes',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ],
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        '📍 Toutes les villes',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    ...villes.map(
                      (v) => DropdownMenuItem<String?>(
                        value: v,
                        child: Text(
                          '📍 $v',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                  onChanged: onVilleChange,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Filtre DISPO (chips) ─────────────────────
          _ChipDispo(
            label: '🌐',
            tooltip: 'En ligne',
            actif: filtreDispo == 'enligne',
            couleur: Colors.green,
            onTap: () =>
                onDispoChange(filtreDispo == 'enligne' ? 'tous' : 'enligne'),
          ),
          const SizedBox(width: 6),
          _ChipDispo(
            label: '✅',
            tooltip: 'Disponible',
            actif: filtreDispo == 'disponible',
            couleur: Colors.blue,
            onTap: () => onDispoChange(
              filtreDispo == 'disponible' ? 'tous' : 'disponible',
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipDispo extends StatelessWidget {
  final String label;
  final String tooltip;
  final bool actif;
  final Color couleur;
  final VoidCallback onTap;

  const _ChipDispo({
    required this.label,
    required this.tooltip,
    required this.actif,
    required this.couleur,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: actif ? couleur : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: actif ? couleur : Colors.grey.shade300),
          ),
          child: Text(label, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

// ==========================================
// WIDGET : CARTE ARTISAN
// ==========================================
class _CarteArtisan extends StatelessWidget {
  final Map<String, dynamic> artisan;
  final String docId;
  final VoidCallback onAppel;

  const _CarteArtisan({
    required this.artisan,
    required this.docId,
    required this.onAppel,
  });

  @override
  Widget build(BuildContext context) {
    final double note = (artisan['note_moyenne'] ?? 0.0).toDouble();
    final int nbAvis = artisan['nombre_avis'] ?? 0;
    final bool isPremium = artisan['isPremium'] == true;
    final bool isOnline = artisan['isOnline'] == true;
    final bool isDisponible = artisan['isDisponible'] == true;
    final String ville = artisan['ville'] ?? '';
    final String quartier = artisan['quartier'] ?? '';

    return Card(
      elevation: isPremium ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isPremium
            ? const BorderSide(color: Colors.amber, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EcranDetailArtisan(artisan: artisan, docId: docId),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Avatar + indicateur En ligne ──────────
              Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blueAccent,
                    backgroundImage:
                        (artisan['photo_profil'] != null &&
                            artisan['photo_profil'].toString().isNotEmpty)
                        ? NetworkImage(artisan['photo_profil'])
                        : null,
                    child:
                        (artisan['photo_profil'] == null ||
                            artisan['photo_profil'].toString().isEmpty)
                        ? const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 28,
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 14),

              // ── Infos ──────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom + Premium
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            artisan['nom'] ?? 'Artisan',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1A237E),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.bolt, color: Colors.amber, size: 13),
                                Text(
                                  'Pro',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Ville
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            quartier.isNotEmpty ? '$ville ($quartier)' : ville,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Note + Badges statut
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              nbAvis == 0
                                  ? 'Nouveau'
                                  : '${note.toStringAsFixed(1)} ($nbAvis avis)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        _BadgeStatut(
                          label: isOnline ? 'En ligne' : 'Hors ligne',
                          couleur: isOnline ? Colors.green : Colors.grey,
                          icone: isOnline
                              ? Icons.circle
                              : Icons.circle_outlined,
                        ),
                        if (isOnline)
                          _BadgeStatut(
                            label: isDisponible ? 'Disponible' : 'Occupé',
                            couleur: isDisponible ? Colors.blue : Colors.orange,
                            icone: isDisponible
                                ? Icons.check_circle_outline
                                : Icons.do_not_disturb_on_outlined,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Bouton appel ───────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isPremium ? Icons.phone_rounded : Icons.lock,
                    color: isPremium ? Colors.green : Colors.grey,
                  ),
                    onPressed: isPremium ? onAppel : null,
                    tooltip: isPremium
                        ? 'Appeler'
                        : 'Cet artisan ne prend pas de nouvelles demandes pour le moment',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge statut (En ligne / Disponible) ──────────────
class _BadgeStatut extends StatelessWidget {
  final String label;
  final Color couleur;
  final IconData icone;

  const _BadgeStatut({
    required this.label,
    required this.couleur,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 8, color: couleur),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: couleur,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// NOUVEAU : ÉCRAN DÉTAIL ARTISAN (AVEC COMMENTAIRES)
// ==========================================
class EcranDetailArtisan extends StatefulWidget {
  final Map<String, dynamic> artisan;
  final String docId;
  const EcranDetailArtisan({
    super.key,
    required this.artisan,
    required this.docId,
  });

  @override
  State<EcranDetailArtisan> createState() => _EcranDetailArtisanState();
}

class _EcranDetailArtisanState extends State<EcranDetailArtisan> {
  final _commentaireController = TextEditingController();

  String get _proprietaireUid =>
      (widget.artisan['uid'] ?? widget.docId).toString();

  bool get _estProprietaire =>
      FirebaseAuth.instance.currentUser?.uid == _proprietaireUid;

  Future<void> _sendNotification(
    String token,
    String title,
    String body,
  ) async {
    const String serverKey =
        'YOUR_SERVER_KEY_HERE'; // Replace with your Firebase Server Key
    final response = await http.post(
      Uri.parse('https://fcm.googleapis.com/fcm/send'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'key=$serverKey',
      },
      body: jsonEncode({
        'to': token,
        'notification': {'title': title, 'body': body},
      }),
    );
    if (response.statusCode == 200) {
      debugPrint('Notification sent successfully');
    } else {
      debugPrint('Failed to send notification: ${response.body}');
    }
  }

  Future<void> _lancerAppel() async {
    final Uri url = Uri(scheme: 'tel', path: widget.artisan['telephone']);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  Future<void> _ajouterCommentaire() async {
    if (_commentaireController.text.trim().isEmpty) return;

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.uid == _proprietaireUid) {
      _afficherErreurAvis(
        'Vous ne pouvez pas laisser un avis sur votre propre fiche.',
      );
      return;
    }

    // Récupérer le nom complet depuis la collection users
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    String auteur;
    if (!userDoc.exists) {
      auteur = user.email?.split('@')[0] ?? "Utilisateur";
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': auteur,
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      auteur =
          (userDoc.data() as Map<String, dynamic>?)?['fullName'] ??
          user.email?.split('@')[0] ??
          "Utilisateur";
    }

    final commentText = _commentaireController.text.trim();
    final commentRef = await FirebaseFirestore.instance
        .collection('artisans')
        .doc(widget.docId)
        .collection('commentaires')
        .add({
          'texte': commentText,
          'auteur': auteur,
          'date': FieldValue.serverTimestamp(),
          'replyText': null,
          'replyTimestamp': null,
        });
    _commentaireController.clear();

    // Créer une notification pour l'artisan
    // Créer une notification pour l'artisan
    await FirebaseFirestore.instance.collection('notifications').add({
      'artisanId': widget.docId,
      'targetUserId': widget.docId, // ✅ LIGNE AJOUTÉE
      'userId': user.uid,
      'userName': auteur,
      'commentText': commentText,
      'commentId': commentRef.id,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _afficherErreurAvis(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  Future<void> _supprimerCommentaire(String commentaireId) async {
    if (!_estProprietaire) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cet avis ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !_estProprietaire) return;

    await FirebaseFirestore.instance
        .collection('artisans')
        .doc(widget.docId)
        .collection('commentaires')
        .doc(commentaireId)
        .delete();
  }

  void _afficherPortfolioPublic(String imageUrl, String description) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                  ),
                ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirePortfolioPublic(bool isPremium) {
    final portfolioRaw = widget.artisan['portfolio'] as List<dynamic>? ?? [];
    final portfolioItems = portfolioRaw
        .map<Map<String, String>?>((item) {
          if (item is String) {
            return {'url': item, 'description': ''};
          }
          if (item is Map) {
            return {
              'url': item['url']?.toString() ?? '',
              'description': item['description']?.toString() ?? '',
            };
          }
          return null;
        })
        .whereType<Map<String, String>>()
        .where((item) => item['url']!.isNotEmpty)
        .toList();

    if (portfolioItems.isEmpty) return const SizedBox.shrink();
    if (!isPremium && !_estProprietaire) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text(
            'Cet artisan ne prend pas de nouvelles demandes pour le moment',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Portfolio',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: portfolioItems.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.9,
          ),
          itemBuilder: (context, index) {
            final item = portfolioItems[index];
            final url = item['url']!;
            return GestureDetector(
              onTap: () => _afficherPortfolioPublic(
                url,
                item['description']!,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _afficherBoiteNotation() {
    if (_estProprietaire) {
      _afficherErreurAvis('Vous ne pouvez pas noter votre propre fiche.');
      return;
    }
    int noteChoisie = 5;
    double noteActuelle = (widget.artisan['note_moyenne'] ?? 0.0).toDouble();
    int nombreAvisActuel = widget.artisan['nombre_avis'] ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Text(
                'Noter cet artisan',
                textAlign: TextAlign.center,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Combien d\'étoiles mérite son travail ?'),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return IconButton(
                          icon: Icon(
                            index < noteChoisie
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 32,
                          ),
                          onPressed: () =>
                              setStateDialog(() => noteChoisie = index + 1),
                        );
                      }),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    double nouvelleNote =
                        ((noteActuelle * nombreAvisActuel) + noteChoisie) /
                        (nombreAvisActuel + 1);
                    await FirebaseFirestore.instance
                        .collection('artisans')
                        .doc(widget.docId)
                        .update({
                          'note_moyenne': nouvelleNote,
                          'nombre_avis': nombreAvisActuel + 1,
                        });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPremium = widget.artisan['isPremium'] == true;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.artisan['nom'] ?? 'Profil',
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.blueAccent.withOpacity(0.1),
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.blueAccent,
                    backgroundImage:
                        (widget.artisan['photo_profil'] != null &&
                            widget.artisan['photo_profil']
                                .toString()
                                .isNotEmpty)
                        ? NetworkImage(widget.artisan['photo_profil'])
                        : null,
                    child:
                        (widget.artisan['photo_profil'] == null ||
                            widget.artisan['photo_profil'].toString().isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    widget.artisan['nom'] ?? '',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.artisan['metier'] ?? '',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      Text(
                        " ${(widget.artisan['note_moyenne'] ?? 0.0).toStringAsFixed(1)} (${widget.artisan['nombre_avis'] ?? 0} avis)",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.location_on,
                      color: Colors.blueAccent,
                    ),
                    title: const Text('Localisation'),
                    subtitle: Text(
                      "${widget.artisan['ville']} - ${widget.artisan['quartier'] ?? ''}",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.phone, color: Colors.blueAccent),
                    title: const Text('Téléphone'),
                    subtitle: Text(
                      isPremium
                          ? (widget.artisan['telephone'] ?? '')
                          : 'Cet artisan ne prend pas de nouvelles demandes pour le moment',
                    ),
                  ),
                  // WhatsApp option supprimée
                  if (widget.artisan['description'] != null &&
                      widget.artisan['description'].toString().isNotEmpty) ...[
                    ListTile(
                      leading: const Icon(
                        Icons.description,
                        color: Colors.blueAccent,
                      ),
                      title: const Text('Description'),
                      subtitle: Text(widget.artisan['description']),
                    ),
                    const SizedBox(height: 10),
                    // Bouton WhatsApp supprimé
                  ],
                  _construirePortfolioPublic(isPremium),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isPremium ? _lancerAppel : null,
                          icon: Icon(
                            isPremium ? Icons.phone : Icons.lock,
                          ),
                          label: Text(
                            isPremium
                                ? "Appeler"
                                : "Cet artisan ne prend pas de nouvelles demandes pour le moment",
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isPremium ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: !isPremium
                              ? null
                              : _estProprietaire
                              ? () => _afficherErreurAvis(
                                    'Vous ne pouvez pas noter votre propre fiche.',
                                  )
                              : _afficherBoiteNotation,
                          icon: const Icon(Icons.star),
                          label: const Text("Noter"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                !isPremium || _estProprietaire
                                    ? Colors.grey
                                    : Colors.amber,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 50, thickness: 2),
                  const Text(
                    "Espace Commentaires",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // LISTE DES COMMENTAIRES
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('artisans')
                        .doc(widget.docId)
                        .collection('commentaires')
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError)
                        return const Center(
                          child: Text(
                            "Aucun message pour le moment",
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        );
                      if (!snapshot.hasData)
                        return const Center(child: CircularProgressIndicator());
                      var commentaires = snapshot.data!.docs;
                      if (commentaires.isEmpty)
                        return const Text(
                          "Aucun commentaire pour le moment. Soyez le premier !",
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        );

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: commentaires.length,
                        itemBuilder: (context, index) {
                          var com =
                              commentaires[index].data()
                                  as Map<String, dynamic>;
                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.grey,
                                child: Icon(Icons.person, color: Colors.white),
                              ),
                              title: Text(
                                com['auteur'] ?? 'Anonyme',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(com['texte'] ?? ''),
                              trailing: _estProprietaire
                                  ? IconButton(
                                      tooltip: 'Supprimer cet avis',
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => _supprimerCommentaire(
                                        commentaires[index].id,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                  // AJOUTER UN COMMENTAIRE
                  if (!isPremium) ...[
                    const Center(
                      child: Text(
                        'Cet artisan ne prend pas de nouvelles demandes pour le moment',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ] else if (_estProprietaire) ...[
                    const Center(
                      child: Text(
                        'Vous ne pouvez pas laisser un avis sur votre propre fiche.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ] else if (FirebaseAuth.instance.currentUser != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _commentaireController,
                            decoration: const InputDecoration(
                              hintText: "Laissez un avis...",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(
                            Icons.send,
                            color: Colors.blueAccent,
                          ),
                          onPressed: _ajouterCommentaire,
                        ),
                      ],
                    ),
                  ] else ...[
                    Center(
                      child: ElevatedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EcranAuthentification(),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'Connectez-vous pour laisser un avis',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ÉCRAN 4 : ESPACE PROFESSIONNEL (CRÉATION)
// ==========================================
class EcranProfessionnel extends StatefulWidget {
  const EcranProfessionnel({super.key});
  @override
  State<EcranProfessionnel> createState() => _EcranProfessionnelState();
}

class _EcranProfessionnelState extends State<EcranProfessionnel> {
  final _cleFormulaire = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController(); // ✅ NOUVEAU
  final _telephoneController = TextEditingController();
  final _quartierController = TextEditingController();
  final _autreVilleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _metierSelectionne;
  String? _villeSelectionnee;
  File? _imageChoisie;
  File? _documentChoisi; // ✅ NOUVEAU
  String? _nomDocument; // ✅ NOUVEAU
  bool _enChargement = false;

  final List<String> _listeMetiers = [
    'Carreleur',
    'Technicien Informatique',
    'Dératiseur / Désinsectiseur',
    'Électricien',
    'Froid / Climatisation',
    'Jardinier',
    'Antenniste',
    'Maçonnerie',
    'Mécanicien (Auto / Moto)',
    'Réparateur d\'électroménager',
    'Menuisier',
    'Peintre',
    'Plombier',
    'Soudeur / Métallique',
  ];

  final List<String> _listeVilles = [
    'Abengourou',
    'Abobo (Abidjan)',
    'Aboisso',
    'Adjamé (Abidjan)',
    'Adzopé',
    'Agboville',
    'Alépé',
    'Anyama',
    'Attécoubé (Abidjan)',
    'Bingerville',
    'Bondoukou',
    'Bonoua',
    'Bouaflé',
    'Bouaké',
    'Bouna',
    'Cocody (Abidjan)',
    'Daloa',
    'Daoukro',
    'Divo',
    'Gagnoa',
    'Grand-Bassam',
    'Issia',
    'Korhogo',
    'Koumassi (Abidjan)',
    'Man',
    'Marcory (Abidjan)',
    'Odienné',
    'Oumé',
    'Plateau (Abidjan)',
    'Port-Bouët (Abidjan)',
    'San-Pédro',
    'Séguéla',
    'Soubré',
    'Treichville (Abidjan)',
    'Vavoua',
    'Yamoussoukro',
    'Yopougon (Abidjan)',
    'Autres',
  ];

  Future<void> _choisirImage() async {
    final picker = ImagePicker();
    final imageSource = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (imageSource != null) {
      setState(() => _imageChoisie = File(imageSource.path));
    }
  }

  // ✅ NOUVEAU : Choisir un document (image JPG/PNG du document)
  Future<void> _choisirDocument() async {
    final picker = ImagePicker();
    final XFile? fichier = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (fichier != null) {
      setState(() {
        _documentChoisi = File(fichier.path);
        _nomDocument = fichier.name;
      });
    }
  }

  Future<String?> _uploaderImage(String uid) async {
    if (_imageChoisie == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('photos_artisans')
          .child('$uid.jpg');
      await ref.putFile(_imageChoisie!);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // ✅ NOUVEAU : Uploader le document
  Future<String?> _uploaderDocument(String uid) async {
    if (_documentChoisi == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('documents_artisans')
          .child('$uid.jpg');
      await ref.putFile(_documentChoisi!);
      return await ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<void> _publierGratuitement() async {
    if (!_cleFormulaire.currentState!.validate()) return;
    setState(() => _enChargement = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      String? photoUrl = await _uploaderImage(uid);
      String? documentUrl = await _uploaderDocument(uid); // ✅ NOUVEAU
      String villeFinale = _villeSelectionnee == 'Autres'
          ? _autreVilleController.text.trim()
          : _villeSelectionnee!;

      await FirebaseFirestore.instance.collection('artisans').doc(uid).set({
        'nom': _nomController.text.trim(),
        'prenom': _prenomController.text.trim(), // ✅ NOUVEAU
        'metier': _metierSelectionne,
        'ville': villeFinale,
        'quartier': _quartierController.text.trim(),
        'telephone': _telephoneController.text.trim(),
        'description': _descriptionController.text.trim(),
        'photo_profil': photoUrl,
        'document_url': documentUrl, // ✅ NOUVEAU
        'document_verifie': false, // ✅ Admin vérifie ensuite
        'date_inscription': FieldValue.serverTimestamp(),
        'uid': uid,
        'note_moyenne': 5.0,
        'nombre_avis': 0,
        'isPremium': false,
        'isOnline': false,
        'isDisponible': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil publié avec succès ! 🚀'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EcranProfil()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'enregistrement.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enChargement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Créer mon profil'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _cleFormulaire,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photo de profil ─────────────────────
              Center(
                child: GestureDetector(
                  onTap: _choisirImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: _imageChoisie != null
                            ? FileImage(_imageChoisie!)
                            : null,
                        child: _imageChoisie == null
                            ? const Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Colors.blueAccent,
                              )
                            : null,
                      ),
                      if (_imageChoisie != null)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    "Ajoutez votre photo de profil",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // ── Nom ─────────────────────────────────
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Veuillez entrer votre nom'
                    : null,
              ),
              const SizedBox(height: 15),

              // ── Prénom ✅ NOUVEAU ────────────────────
              TextFormField(
                controller: _prenomController,
                decoration: const InputDecoration(
                  labelText: 'Prénom *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => (v == null || v.isEmpty)
                    ? 'Veuillez entrer votre prénom'
                    : null,
              ),
              const SizedBox(height: 15),

              // ── Métier ───────────────────────────────
              DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sélectionnez votre métier *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.handyman_outlined),
                ),
                value: _metierSelectionne,
                items: _listeMetiers
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text(m, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _metierSelectionne = v),
                validator: (v) =>
                    v == null ? 'Veuillez choisir un métier' : null,
              ),
              const SizedBox(height: 15),

              // ── Ville ────────────────────────────────
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Ville ou Commune *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                value: _villeSelectionnee,
                items: _listeVilles
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _villeSelectionnee = v),
                validator: (v) =>
                    v == null ? 'Veuillez choisir votre localisation' : null,
              ),
              if (_villeSelectionnee == 'Autres') ...[
                const SizedBox(height: 15),
                TextFormField(
                  controller: _autreVilleController,
                  decoration: const InputDecoration(
                    labelText: 'Précisez votre ville',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 15),

              // ── Quartier ─────────────────────────────
              TextFormField(
                controller: _quartierController,
                decoration: const InputDecoration(
                  labelText: 'Quartier (ex: Toits Rouges)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),
              const SizedBox(height: 15),

              // ── Téléphone ────────────────────────────
              TextFormField(
                controller: _telephoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) =>
                    (v == null || v.length < 8) ? 'Numéro invalide' : null,
              ),
              const SizedBox(height: 15),

              // ── Description ──────────────────────────
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description de votre métier',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                  hintText:
                      'Ex: Je suis électricien avec 5 ans d\'expérience...',
                ),
              ),
              const SizedBox(height: 24),

              // ── Document facultatif ✅ NOUVEAU ───────
              const Text(
                'Document justificatif (facultatif)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'CNI, diplôme, certificat ou tout document prouvant votre expertise.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 10),

              GestureDetector(
                onTap: _choisirDocument,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _documentChoisi != null
                        ? Colors.green.shade50
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _documentChoisi != null
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: _documentChoisi != null
                      ? Row(
                          children: [
                            // Aperçu miniature
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _documentChoisi!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '✅ Document ajouté',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _nomDocument ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => setState(() {
                                _documentChoisi = null;
                                _nomDocument = null;
                              }),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.upload_file_outlined,
                              color: Colors.blueAccent,
                              size: 28,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Appuyez pour ajouter un document',
                                style: TextStyle(color: Colors.blueAccent),
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              // Badge vérifié si document ajouté
              if (_documentChoisi != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, color: Colors.amber, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Document en attente de vérification par l\'admin',
                        style: TextStyle(fontSize: 11, color: Colors.amber),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // ── Bouton Publier ───────────────────────
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: _enChargement ? null : _publierGratuitement,
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: _enChargement
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          'Publier mon profil gratuitement',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// ÉCRAN MON PROFIL (AVEC MODIFICATION ET PHOTO)
// ==========================================

class EcranProfil extends StatefulWidget {
  final bool estNouveau;
  const EcranProfil({super.key, this.estNouveau = false});

  @override
  State<EcranProfil> createState() => _EcranProfilState();
}

class _EcranProfilState extends State<EcranProfil> {
  File? _imageChoisie;
  bool _enChargement = false;
  String? _currentPaymentReference;

  Future<String> _determinerRoleUtilisateur(String uid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (userDoc.exists) {
      final data = userDoc.data();
      return data?['role'] == 'artisan' ? 'artisan' : 'client';
    }
    return 'client';
  }

  Future<String> _determinerContactUtilisateur(User utilisateur) async {
    final email = utilisateur.email;
    if (email == null || !email.endsWith('@serviceproci.app')) {
      return email ?? 'Email inconnu';
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(utilisateur.uid)
        .get();
    final data = userDoc.data();
    final numero = utilisateur.phoneNumber ?? data?['telephone']?.toString();
    if (numero == null || numero.isEmpty) return 'Numéro de téléphone';
    if (numero.startsWith('+')) return numero;
    return formaterNumeroIvoirien(numero) ?? numero;
  }

  Future<void> _choisirImage() async {
    final picker = ImagePicker();
    final imageSource = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (imageSource != null) {
      setState(() => _imageChoisie = File(imageSource.path));
    }
  }

  Future<String?> _uploaderImageClient(String uid) async {
    if (_imageChoisie == null) return null;
    try {
      if (FirebaseAuth.instance.currentUser == null) return null;
      final ref = FirebaseStorage.instance
          .ref()
          .child('photos_clients')
          .child('$uid.jpg');
      await ref.putFile(_imageChoisie!);
      return await ref.getDownloadURL();
    } catch (e) {
      _afficherErreur('Erreur lors du téléchargement de la photo.');
      return null;
    }
  }

  Future<String?> _uploaderImage(String uid) async {
    if (_imageChoisie == null) return null;
    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('photos_artisans')
          .child('$uid.jpg');
      await ref.putFile(_imageChoisie!);
      return await ref.getDownloadURL();
    } catch (e) {
      _afficherErreur('Erreur lors du téléchargement de la photo.');
      return null;
    }
  }

  Future<void> _ajouterPhotoPortfolio() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    String? description = await showDialog<String>(
      context: context,
      builder: (context) {
        final descriptionController = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Ajouter une réalisation',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Décrivez brièvement cette réalisation :'),
              const SizedBox(height: 15),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Ex: Réparation de plomberie, peinture murale...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                maxLength: 200,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(
                descriptionController.text.trim().isEmpty
                    ? 'Réalisation sans titre'
                    : descriptionController.text.trim(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ajouter'),
            ),
          ],
        );
      },
    );

    description ??= 'Réalisation sans titre';

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Téléchargement en cours...',
                style: TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      String fileName =
          'portfolio_${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child(
        'artisans/$userId/$fileName',
      );
      await ref.putFile(File(image.path));
      String url = await ref.getDownloadURL();

      if (!mounted) return;
      await FirebaseFirestore.instance
          .collection('artisans')
          .doc(userId)
          .update({
            'portfolio': FieldValue.arrayUnion([
              {
                'url': url,
                'description': description,
                'timestamp': Timestamp.now(),
              },
            ]),
          });

      if (mounted) Navigator.of(context).pop();
      _afficherErreur("Photo ajoutée avec succès !");
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      _afficherErreur("Erreur lors de l'ajout");
    }
  }

  Future<void> _supprimerPhotoPortfolio(
    String docId,
    Map<String, dynamic> portfolioItem,
  ) async {
    final url = portfolioItem['url'] as String?;
    if (url == null || url.isEmpty) {
      _afficherErreur('Impossible de supprimer cette photo.');
      return;
    }
    setState(() => _enChargement = true);
    try {
      try {
        await FirebaseStorage.instance.refFromURL(url).delete();
      } catch (_) {}
      final rawItem = portfolioItem['raw'] ?? portfolioItem;
      await FirebaseFirestore.instance.collection('artisans').doc(docId).update(
        {
          'portfolio': FieldValue.arrayRemove([rawItem]),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo supprimée du portfolio'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _afficherErreur('Impossible de supprimer la photo du portfolio.');
    } finally {
      if (mounted) setState(() => _enChargement = false);
    }
  }

  Future<void> _confirmerSuppressionPortfolio(
    String docId,
    Map<String, dynamic> portfolioItem,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la photo ?'),
          content: const Text(
            'Voulez-vous vraiment supprimer cette photo du portfolio ? Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _supprimerPhotoPortfolio(docId, portfolioItem);
    }
  }

  void _afficherPortfolioPleinEcran(String imageUrl, String description) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(0),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: InteractiveViewer(
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Center(
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                      ),
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _afficherErreur(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _afficherBoitePhotoProfileClient(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            'Changer ma photo de profil',
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_imageChoisie != null)
                  Column(
                    children: [
                      const Text(
                        'Aperçu de la nouvelle photo:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: FileImage(_imageChoisie!),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ElevatedButton.icon(
                  onPressed: _choisirImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Sélectionner une image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            if (_imageChoisie != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _enChargement = true);
                  final messenger = ScaffoldMessenger.of(context);
                  String? photoUrl = await _uploaderImageClient(uid);
                  if (photoUrl != null) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .update({'photo_profil': photoUrl});
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Photo de profil mise à jour ! 🎉'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    if (mounted) setState(() => _imageChoisie = null);
                  }
                  if (mounted) setState(() => _enChargement = false);
                },
                child: const Text('Enregistrer'),
              ),
          ],
        );
      },
    );
  }

  void _afficherBoitePhotoProfile(
    BuildContext context,
    String docId,
    Map<String, dynamic> donneesActuelles,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text('Changer ma photo', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_imageChoisie != null)
                  Column(
                    children: [
                      const Text(
                        'Aperçu de la nouvelle photo:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      CircleAvatar(
                        radius: 60,
                        backgroundImage: FileImage(_imageChoisie!),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ElevatedButton.icon(
                  onPressed: _choisirImage,
                  icon: const Icon(Icons.image),
                  label: const Text('Sélectionner une image'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Annuler',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            if (_imageChoisie != null)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  setState(() => _enChargement = true);
                  final messenger = ScaffoldMessenger.of(context);
                  final utilisateur = FirebaseAuth.instance.currentUser;
                  if (utilisateur != null) {
                    String? photoUrl = await _uploaderImage(utilisateur.uid);
                    if (photoUrl != null) {
                      if (docId.isEmpty) return;
                      await FirebaseFirestore.instance
                          .collection('artisans')
                          .doc(docId)
                          .update({'photo_profil': photoUrl});
                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Photo mise à jour avec succès ! 🎉'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                      if (mounted) setState(() => _imageChoisie = null);
                    }
                  }
                  if (mounted) setState(() => _enChargement = false);
                },
                child: const Text('Enregistrer'),
              ),
          ],
        );
      },
    );
  }

  void _modifierProfil(
    BuildContext context,
    String docId,
    Map<String, dynamic> donneesActuelles,
  ) {
    final nomController = TextEditingController(text: donneesActuelles['nom']);
    final telController = TextEditingController(
      text: donneesActuelles['telephone'],
    );
    final quartierController = TextEditingController(
      text: donneesActuelles['quartier'] ?? '',
    );
    final descriptionController = TextEditingController(
      text: donneesActuelles['description'] ?? '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Modifier mes informations',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Métier: ${donneesActuelles['metier']}",
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: quartierController,
                  decoration: const InputDecoration(
                    labelText: 'Quartier (ex: Toits Rouges)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: telController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description du métier',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('artisans')
                          .doc(docId)
                          .update({
                            'nom': nomController.text.trim(),
                            'quartier': quartierController.text.trim(),
                            'telephone': telController.text.trim(),
                            'description': descriptionController.text.trim(),
                          });
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text(
                      'Enregistrer',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _repondreCommentaire(
    BuildContext context,
    String artisanId,
    String comId,
    Map<String, dynamic> com,
  ) {
    final replyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Répondre au commentaire'),
          content: TextField(
            controller: replyController,
            decoration: const InputDecoration(labelText: 'Votre réponse'),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (replyController.text.trim().isNotEmpty) {
                  await FirebaseFirestore.instance
                      .collection('artisans')
                      .doc(artisanId)
                      .collection('commentaires')
                      .doc(comId)
                      .update({
                        'replyText': replyController.text.trim(),
                        'replyTimestamp': FieldValue.serverTimestamp(),
                      });
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Envoyer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _ouvrirPaiementPremium(
    BuildContext context,
    String docId,
  ) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'creerLienPaiementPremium',
      );
      final result = await callable.call({'docId': docId});
      final lien = result.data['checkout_url'] as String?;
      if (lien == null) throw Exception('Lien de paiement introuvable');

      final Uri url = Uri.parse(lien);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
      setState(() => _currentPaymentReference = 'initiated');
    } catch (e) {
      _afficherErreur('Erreur lors de la création du paiement.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final utilisateur = FirebaseAuth.instance.currentUser;
    if (utilisateur == null)
      return const Scaffold(
        body: Center(child: Text('Utilisateur non connecté')),
      );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: FutureBuilder<String>(
          future: _determinerRoleUtilisateur(utilisateur.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError)
              return const Center(
                child: Text('Erreur lors du chargement du profil'),
              );

            final role = snapshot.data ?? 'client';
            final isArtisan = role == 'artisan';

            return Column(
              children: [
                Expanded(
                  child: isArtisan
                      ? _construireInterfaceArtisan(utilisateur)
                      : _construireInterfaceClient(utilisateur),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
  Widget _construireActionsCompte() {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 20),
      child: Column(
        children: [
          ElevatedButton.icon(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final artisanSnap = await FirebaseFirestore.instance
                    .collection('artisans')
                    .where('uid', isEqualTo: user.uid)
                    .limit(1)
                    .get();

                if (artisanSnap.docs.isNotEmpty) {
                  await artisanSnap.docs.first.reference.update({
                    'isOnline': false,
                    'isDisponible': false,
                  });
                }
              }

              await FirebaseAuth.instance.signOut();
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _supprimerCompte,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              'Supprimer mon compte',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _supprimerCompte() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Supprimer mon compte'),
        content: const Text(
          'Cette action est irréversible. Votre profil, vos photos et vos documents seront définitivement supprimés.\n\nContinuer ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Suppression en cours...')),
          ],
        ),
      ),
    );

    try {
      await _executerSuppressionCompte();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const EcranAuthentification()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      if (e.code == 'requires-recent-login') {
        final reauthOk = await _reauthentifierPourSuppression();
        if (reauthOk) await _supprimerCompte();
      } else {
        _afficherErreur('Erreur : ${e.message}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _afficherErreur('Erreur lors de la suppression du compte.');
    }
  }

  Future<bool> _reauthentifierPourSuppression() async {
    final motDePasseController = TextEditingController();
    final motDePasse = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Confirmez votre mot de passe'),
        content: TextField(
          controller: motDePasseController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Mot de passe'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, motDePasseController.text),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (motDePasse == null || motDePasse.isEmpty) return false;

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: motDePasse,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      _afficherErreur('Mot de passe incorrect.');
      return false;
    }
  }

  Future<void> _executerSuppressionCompte() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    final artisanDoc = await FirebaseFirestore.instance
        .collection('artisans')
        .doc(uid)
        .get();

    if (artisanDoc.exists) {
      final data = artisanDoc.data() as Map<String, dynamic>;
      try {
        await FirebaseStorage.instance
            .ref()
            .child('photos_artisans')
            .child('$uid.jpg')
            .delete();
      } catch (_) {}
      try {
        await FirebaseStorage.instance
            .ref()
            .child('documents_artisans')
            .child('$uid.jpg')
            .delete();
      } catch (_) {}
      final portfolio = (data['portfolio'] as List?) ?? [];
      for (final item in portfolio) {
        final url = (item as Map)['url'] as String?;
        if (url != null && url.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(url).delete();
          } catch (_) {}
        }
      }
      await FirebaseFirestore.instance
          .collection('artisans')
          .doc(uid)
          .delete();
    } else {
      try {
        await FirebaseStorage.instance
            .ref()
            .child('photos_clients')
            .child('$uid.jpg')
            .delete();
      } catch (_) {}
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
    }

    await user.delete();
  }

  Widget _construireInterfaceClient(User utilisateur) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(utilisateur.uid)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final statut =
              userData['statutVerification']?.toString() ?? 'non_soumis';

          final libelleStatut = switch (statut) {
            'valide' => 'Identité vérifiée',
            'en_attente' => 'Vérification en cours',
            'rejete' => 'Vérification rejetée',
            _ => 'Non vérifiée',
          };

          final couleurStatut = switch (statut) {
            'valide' => Colors.green,
            'en_attente' => Colors.orange,
            'rejete' => Colors.red,
            _ => Colors.grey,
          };

          final nomComplet =
              (userData['fullName']?.toString().trim().isNotEmpty ?? false)
                  ? userData['fullName'].toString()
                  : '${userData['prenom'] ?? ''} ${userData['nom'] ?? ''}'
                      .trim();

          final telephone = utilisateur.phoneNumber ??
              userData['telephone']?.toString() ??
              'Numéro non renseigné';

          return ListView(
            children: [
                            Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
                        onTap: () => _afficherBoitePhotoProfileClient(
                          context,
                          utilisateur.uid,
                        ),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 42,
                              backgroundColor: Colors.blueAccent,
                              backgroundImage:
                                  (userData['photo_profil']?.toString()
                                              .isNotEmpty ??
                                          false)
                                      ? NetworkImage(
                                          userData['photo_profil'].toString(),
                                        )
                                      : null,
                              child: (userData['photo_profil']?.toString()
                                          .isNotEmpty ??
                                      false)
                                  ? null
                                  : const Icon(
                                      Icons.person,
                                      size: 42,
                                      color: Colors.white,
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.amber,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                  onPressed: () =>
                                      _afficherBoitePhotoProfileClient(
                                    context,
                                    utilisateur.uid,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      nomComplet.isEmpty ? 'Client' : nomComplet,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Client',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Chip(
                        avatar: Icon(
                          statut == 'valide'
                              ? Icons.verified
                              : Icons.verified_user_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          libelleStatut,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: couleurStatut,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'COMPTE',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      margin: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              statut == 'valide'
                                  ? Icons.verified
                                  : Icons.verified_user_outlined,
                              color: couleurStatut,
                            ),
                            title: const Text('Vérifier mon identité'),
                            subtitle: Text(libelleStatut),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const EcranVerificationClient(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: Icon(
                              Icons.badge_outlined,
                              color: statut == 'valide'
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            title: const Text('Afficher mon badge'),
                            subtitle: Text(
                              statut == 'valide'
                                  ? 'Télécharger ou imprimer'
                                  : 'Disponible après validation',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: statut == 'valide'
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const EcranBadgeIdentite(),
                                      ),
                                    )
                                : null,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.phone_outlined,
                              color: Colors.blueAccent,
                            ),
                            title: const Text('Numéro de téléphone'),
                            subtitle: Text(telephone),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profil enregistré avec succès !'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer mon profil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
               _construireActionsCompte(),
            ],
          );
        },
      ),
    );
  }

  Widget _construireCarteVerificationArtisan(String uid) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final statut = data['statutVerification']?.toString() ?? 'non_soumis';

        final String message;
        final Color couleur;
        final bool peutSoumettre = statut != 'en_attente' && statut != 'valide';
        switch (statut) {
          case 'en_attente':
            message = 'Vérification en cours';
            couleur = Colors.orange;
          case 'valide':
            message = 'Identité vérifiée';
            couleur = Colors.green;
          case 'rejete':
            message = 'Vérification rejetée : vous pouvez renvoyer vos documents';
            couleur = Colors.red;
          default:
            message = 'Votre identité n’est pas encore vérifiée';
            couleur = Colors.grey;
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Card(
            child: ListTile(
              leading: Icon(
                statut == 'valide'
                    ? Icons.verified
                    : Icons.verified_user_outlined,
                color: couleur,
              ),
              title: const Text('Vérification d’identité'),
              subtitle: Text(message),
              trailing: statut == 'valide'
                  ? const Icon(Icons.badge_outlined)
                  : peutSoumettre
                      ? const Icon(Icons.chevron_right)
                      : null,
              onTap: peutSoumettre
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EcranVerificationArtisan(),
                        ),
                      )
                  : statut == 'valide'
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const EcranBadgeIdentite(),
                            ),
                          )
                      : null,
            ),
          ),
        );
      },
    );
  }

  Widget _construireInterfaceArtisan(User utilisateur) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('artisans')
            .where('uid', isEqualTo: utilisateur.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Vous n'avez pas encore de fiche artisan.",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    // ✅ Vérification email avant création fiche
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;

                    // Recharger le statut Firebase
                    await user.reload();
                    final userActuel = FirebaseAuth.instance.currentUser;

                    if (userActuel == null) return;

                    // ✅ Vérifier si email vérifié pour les seuls comptes email
                    final estCompteTelephone = userActuel.providerData.any(
                      (provider) => provider.providerId == 'phone',
                    );
                    if (!estCompteTelephone && !userActuel.emailVerified) {
                      if (mounted) {
                        // Déconnecter et rediriger vers vérification
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            title: const Row(
                              children: [
                                Icon(
                                  Icons.warning_rounded,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 8),
                                Text('Email non vérifié'),
                              ],
                            ),
                            content: const Text(
                              'Vous devez vérifier votre adresse email avant de créer votre fiche artisan.\n\nVeuillez vérifier votre boîte mail et cliquer sur le lien de validation.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  // Renvoyer email de vérification
                                  await userActuel.sendEmailVerification();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email de vérification renvoyé !',
                                        ),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                child: const Text('Renvoyer l\'email'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(context);
                                  // Déconnecter
                                  await FirebaseAuth.instance.signOut();
                                  if (mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const EcranAccueil(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Se déconnecter'),
                              ),
                            ],
                          ),
                        );
                      }
                      return;
                    }

                    // ✅ Email vérifié → accès autorisé
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EcranProfessionnel(),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Créer ma fiche artisan"),
                ),
              ],
            );
          }

          var document = snapshot.data!.docs.first;
          var artisan = document.data() as Map<String, dynamic>;
          var docId = document.id;

          return ListView(
            children: [
              // 🔥 HEADER PROFIL
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueAccent, Colors.blue.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 25),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          _afficherBoitePhotoProfile(context, docId, artisan),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            backgroundImage:
                                (artisan['photo_profil'] != null &&
                                    artisan['photo_profil']
                                        .toString()
                                        .isNotEmpty)
                                ? NetworkImage(artisan['photo_profil'])
                                : null,
                            child:
                                (artisan['photo_profil'] == null ||
                                    artisan['photo_profil'].toString().isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.blueAccent,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.amber,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                onPressed: () => _afficherBoitePhotoProfile(
                                  context,
                                  docId,
                                  artisan,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          artisan['nom'] ?? '',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (artisan['isPremium'] == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '⭐ PREMIUM',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artisan['metier'] ?? '',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          "${(artisan['note_moyenne'] ?? 0.0).toStringAsFixed(1)} (${artisan['nombre_avis'] ?? 0} avis)",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ✅ TOGGLE DISPONIBILITÉ — juste après le header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ToggleDisponibilite(
                  docId: docId,
                  isOnline: artisan['isOnline'] == true,
                  isDisponible: artisan['isDisponible'] == true,
                ),
              ),

              _construireCarteVerificationArtisan(utilisateur.uid),

              // 🔥 INFOS
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.location_on,
                              color: Colors.blueAccent,
                            ),
                            title: const Text('Localisation'),
                            subtitle: Text(
                              "${artisan['ville']} - ${artisan['quartier'] ?? ''}",
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(
                              Icons.phone,
                              color: Colors.blueAccent,
                            ),
                            title: const Text('Téléphone'),
                            subtitle: Text(artisan['telephone'] ?? ''),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),

                    if (!(artisan['isPremium'] ?? false)) ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () =>
                              _ouvrirPaiementPremium(context, docId),
                          icon: const Icon(Icons.star),
                          label: const Text(
                            'Devenir Premium (2000 FCFA)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_currentPaymentReference != null) ...[
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Rafraîchir mon statut'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () =>
                            _modifierProfil(context, docId, artisan),
                        icon: const Icon(Icons.edit),
                        label: const Text(
                          'Modifier mes informations',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Portfolio
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Portfolio',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.add_a_photo,
                            color: Colors.blueAccent,
                          ),
                          tooltip: 'Ajouter une photo au portfolio',
                          onPressed: () => _ajouterPhotoPortfolio(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Builder(
                      builder: (context) {
                        final portfolioRaw =
                            artisan['portfolio'] as List<dynamic>?;
                        final portfolioItems =
                            portfolioRaw
                                ?.map((item) {
                                  if (item is String)
                                    return {
                                      'url': item,
                                      'description': '',
                                      'raw': item,
                                    };
                                  if (item is Map<String, dynamic>)
                                    return {
                                      'url': item['url'] ?? '',
                                      'description': item['description'] ?? '',
                                      'raw': item,
                                    };
                                  if (item is Map)
                                    return {
                                      'url': item['url']?.toString() ?? '',
                                      'description':
                                          item['description']?.toString() ?? '',
                                      'raw': item,
                                    };
                                  return null;
                                })
                                .whereType<Map<String, dynamic>>()
                                .toList() ??
                            [];

                        if (portfolioItems.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              'Aucune photo dans le portfolio pour le moment.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          );
                        }

                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          children: portfolioItems.map((item) {
                            final url = item['url'] as String? ?? '';
                            final description =
                                item['description'] as String? ?? '';
                            if (url.isEmpty)
                              return Container(color: Colors.grey.shade200);
                            return GestureDetector(
                              onTap: () => _afficherPortfolioPleinEcran(
                                url,
                                description,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: Image.network(
                                            url,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            loadingBuilder:
                                                (context, child, progress) {
                                                  if (progress == null)
                                                    return child;
                                                  return const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  );
                                                },
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Container(
                                                      color:
                                                          Colors.grey.shade200,
                                                      child: const Icon(
                                                        Icons.broken_image,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: IconButton(
                                              iconSize: 18,
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  _confirmerSuppressionPortfolio(
                                                    docId,
                                                    item,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description.isEmpty ? '' : description,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const Divider(height: 40, thickness: 2),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Mes Commentaires",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('artisans')
                          .doc(docId)
                          .collection('commentaires')
                          .orderBy('date', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError)
                          return const Center(
                            child: Text(
                              "Aucun message pour le moment",
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          );
                        if (!snapshot.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        var commentaires = snapshot.data!.docs;
                        if (commentaires.isEmpty)
                          return const Text(
                            "Aucun commentaire pour le moment.",
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: commentaires.length,
                          itemBuilder: (context, index) {
                            var com =
                                commentaires[index].data()
                                    as Map<String, dynamic>;
                            var comId = commentaires[index].id;
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const CircleAvatar(
                                          radius: 16,
                                          backgroundColor: Colors.blueAccent,
                                          child: Icon(
                                            Icons.person,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          com['auteur'] ?? 'Anonyme',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      com['texte'] ?? '',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    if (com['replyText'] != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '↩ Votre réponse: ${com['replyText']}',
                                          style: const TextStyle(
                                            fontStyle: FontStyle.italic,
                                            color: Colors.blueAccent,
                                          ),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    if (com['replyText'] == null)
                                      TextButton.icon(
                                        onPressed: () => _repondreCommentaire(
                                          context,
                                          docId,
                                          comId,
                                          com,
                                        ),
                                        icon: const Icon(Icons.reply, size: 16),
                                        label: const Text('Répondre'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.blueAccent,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _construireActionsCompte(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// WIDGET : TOGGLE DISPONIBILITÉ ARTISAN
// ==========================================
class _ToggleDisponibilite extends StatelessWidget {
  final String docId;
  final bool isOnline;
  final bool isDisponible;

  const _ToggleDisponibilite({
    required this.docId,
    required this.isOnline,
    required this.isDisponible,
  });

  Future<void> _toggleDispo(BuildContext context, bool nouvelleValeur) async {
    await FirebaseFirestore.instance.collection('artisans').doc(docId).update({
      'isDisponible': nouvelleValeur,
      if (nouvelleValeur) 'isOnline': true,
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nouvelleValeur
                ? '✅ Vous êtes maintenant disponible'
                : '🔴 Vous êtes maintenant occupé',
          ),
          backgroundColor: nouvelleValeur ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDisponible ? Colors.green.shade200 : Colors.orange.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDisponible
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDisponible
                  ? Icons.check_circle_rounded
                  : Icons.do_not_disturb_on_rounded,
              color: isDisponible ? Colors.green : Colors.orange,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDisponible ? 'Je suis disponible' : 'Je suis occupé',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDisponible
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
                Text(
                  isDisponible
                      ? 'Les clients peuvent vous contacter'
                      : 'Vous n\'acceptez pas de nouvelles missions',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Switch(
            value: isDisponible,
            activeColor: Colors.green,
            inactiveThumbColor: Colors.orange,
            inactiveTrackColor: Colors.orange.shade100,
            onChanged: (val) => _toggleDispo(context, val), // ✅ Toujours actif
          ),
        ],
      ),
    );
  }
}

// ==========================================
// NOUVELLES PAGES : NOTIFICATIONS ET MESSAGES
// ==========================================

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                size: 80,
                color: Colors.grey,
              ),
              const SizedBox(height: 20),
              const Text(
                'Connectez-vous pour voir\nvos notifications',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EcranAuthentification(),
                  ),
                ),
                icon: const Icon(Icons.login),
                label: const Text('Se connecter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('targetUserId', isEqualTo: user.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // Debug: Log de l'état du snapshot
          debugPrint('📡 Snapshot state: ${snapshot.connectionState}');
          debugPrint('📡 Has data: ${snapshot.hasData}');
          debugPrint('📡 Has error: ${snapshot.hasError}');
          if (snapshot.hasError) {
            debugPrint('📡 Error: ${snapshot.error}');
          }
          if (snapshot.hasData) {
            debugPrint('📡 Documents count: ${snapshot.data!.docs.length}');
          }

          // Gestion du chargement
          if (snapshot.connectionState == ConnectionState.waiting) {
            debugPrint('⏳ Chargement des notifications...');
            return const Center(child: CircularProgressIndicator());
          }

          // Gestion des erreurs
          if (snapshot.hasError) {
            // Afficher l'erreur dans la console de débogage
            debugPrint(snapshot.error.toString());

            return Center(
              child: Text(
                'Erreur: ${snapshot.error.toString()}',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }

          // Gestion du cas où il n'y a pas de données
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            debugPrint('📭 Aucune notification trouvée');
            return const Center(
              child: Text(
                'Aucune notification reçue',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            );
          }

          final notifications = snapshot.data!.docs;
          debugPrint('📬 ${notifications.length} notifications chargées');

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index].data() as Map<String, dynamic>;
              final isRead = notif['isRead'] ?? false;
              final userName = notif['userName'] ?? 'Utilisateur';
              final commentText = notif['commentText'] ?? '';
              final excerpt = commentText.length > 50
                  ? '${commentText.substring(0, 50)}...'
                  : commentText;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: isRead ? Colors.white : Colors.blue.shade50,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey : Colors.blueAccent,
                    child: Icon(
                      isRead ? Icons.notifications_none : Icons.notifications,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    notif['type'] == 'verification_identite'
                        ? (notif['title'] ?? 'Mise à jour de vérification')
                        : 'Nouveau commentaire de $userName',
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    notif['type'] == 'verification_identite'
                        ? (notif['body'] ?? '')
                        : excerpt,
                  ),
                  trailing: isRead
                      ? null
                      : const Icon(
                          Icons.circle,
                          color: Colors.blueAccent,
                          size: 12,
                        ),
                  onTap: () {
                    // Debug: Log avant de marquer comme lu
                    debugPrint(
                      '🔔 Notification tap - ID: ${notifications[index].id}',
                    );
                    debugPrint('🔔 User ID: ${user.uid}');
                    debugPrint('🔔 Notification data: $notif');

                    // Marquer comme lu
                    FirebaseFirestore.instance
                        .collection('notifications')
                        .doc(notifications[index].id)
                        .update({'isRead': true})
                        .then((_) {
                          debugPrint('✅ Notification marquée comme lue');
                        })
                        .catchError((error) {
                          debugPrint('❌ Erreur lors du marquage comme lu: $error');
                        });

                    // Debug: Log avant navigation
                    debugPrint('🚀 Navigation vers MessageDetailPage');

                    // Naviguer vers le détail
                    Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MessageDetailPage(
                              notificationId: notifications[index].id,
                              notificationData: notif,
                            ),
                          ),
                        )
                        .then((_) {
                          debugPrint('✅ Retour de MessageDetailPage');
                        })
                        .catchError((error) {
                          debugPrint('❌ Erreur de navigation: $error');
                        });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class MessageDetailPage extends StatefulWidget {
  final String notificationId;
  final Map<String, dynamic> notificationData;

  const MessageDetailPage({
    super.key,
    required this.notificationId,
    required this.notificationData,
  });

  @override
  State<MessageDetailPage> createState() => _MessageDetailPageState();
}

class _MessageDetailPageState extends State<MessageDetailPage> {
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Debug: Log à l'ouverture de la page
    debugPrint('📄 MessageDetailPage ouverte');
    debugPrint('📄 Notification ID: ${widget.notificationId}');
    debugPrint('📄 Notification data: ${widget.notificationData}');
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.notificationData['userName'] ?? 'Utilisateur';
    final commentText = widget.notificationData['commentText'] ?? '';
    final commentId = widget.notificationData['commentId'];
    final artisanId = widget.notificationData['artisanId'];

    // Debug: Log des données extraites
    debugPrint('👤 UserName: $userName');
    debugPrint('💬 CommentText: $commentText');
    debugPrint('🆔 CommentId: $commentId');
    debugPrint('🔧 ArtisanId: $artisanId');

    return Scaffold(
      appBar: AppBar(
        title: Text('Message de $userName'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Commentaire de $userName :',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueAccent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            commentText,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: const InputDecoration(
                      hintText: 'Tapez votre réponse...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    minLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    debugPrint('📤 Tentative d\'envoi de réponse');
                    debugPrint('📤 Reply text: "${_replyController.text.trim()}"');
                    debugPrint('📤 CommentId: $commentId');
                    debugPrint('📤 ArtisanId: $artisanId');

                    if (_replyController.text.trim().isNotEmpty &&
                        commentId != null &&
                        artisanId != null) {
                      debugPrint('✅ Conditions remplies pour l\'envoi');
                      try {
                        // Mettre à jour le commentaire avec la réponse
                        debugPrint('🔄 Mise à jour Firestore...');
                        await FirebaseFirestore.instance
                            .collection('artisans')
                            .doc(artisanId)
                            .collection('commentaires')
                            .doc(commentId)
                            .update({
                              'replyText': _replyController.text.trim(),
                              'replyTimestamp': FieldValue.serverTimestamp(),
                            });

                        debugPrint('✅ Mise à jour Firestore réussie');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Réponse envoyée'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        debugPrint('❌ Erreur lors de l\'envoi: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('❌ Erreur: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else {
                      debugPrint('❌ Conditions non remplies:');
                      debugPrint(
                        '❌ - Text non vide: ${_replyController.text.trim().isNotEmpty}',
                      );
                      debugPrint('❌ - CommentId non null: ${commentId != null}');
                      debugPrint('❌ - ArtisanId non null: ${artisanId != null}');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Envoyer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }
}

// ==========================================
// RESTE DU CODE (Menu, Auth, Support, Tutoriel)
// ==========================================
class MenuLateral extends StatefulWidget {
  const MenuLateral({super.key});

  @override
  State<MenuLateral> createState() => _MenuLateralState();
}

class _MenuLateralState extends State<MenuLateral> {
  String _cacheSize = '0 Ko';
  bool _isClearingCache = false;

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final cacheSize = await _getDirectorySize(cacheDir);
      if (mounted) {
        setState(() {
          _cacheSize = _formatBytes(cacheSize);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _cacheSize = 'N/A';
        });
      }
    }
  }

  Future<int> _getDirectorySize(Directory dir) async {
    int size = 0;
    try {
      final files = dir.listSync(recursive: true);
      for (final file in files) {
        if (file is File) {
          size += await file.length();
        }
      }
    } catch (e) {
      // Ignore les erreurs de lecture
    }
    return size;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  Future<void> _clearCache() async {
    setState(() {
      _isClearingCache = true;
    });

    try {
      final cacheDir = await getTemporaryDirectory();
      await _deleteDirectoryContents(cacheDir);
      await _calculateCacheSize();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache effacé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'effacement du cache'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isClearingCache = false;
        });
      }
    }
  }

  Future<void> _deleteDirectoryContents(Directory dir) async {
    try {
      final contents = dir.listSync();
      for (final entity in contents) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      }
    } catch (e) {
      // Ignore les erreurs de suppression
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handyman, size: 60, color: Colors.white),
                SizedBox(height: 10),
                Text(
                  'Service Pro CI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.blueAccent),
            title: const Text('Mon Profil Artisan'),
            onTap: () {
              Navigator.pop(context);
              if (FirebaseAuth.instance.currentUser != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EcranProfil()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EcranAuthentification(),
                  ),
                );
              }
            },
          ),

          if (FirebaseAuth.instance.currentUser?.uid == serviceProAdminUid)
            ListTile(
              leading: const Icon(Icons.verified_user, color: Colors.orange),
              title: const Text('Modération des vérifications'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EcranModerationVerifications(),
                  ),
                );
              },
            ),

          // Ligne de séparation pour les paramètres
          const Divider(height: 1, thickness: 1),

          // Section Paramètres
          ListTile(
            title: Text(
              'Pays',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            trailing: Text(
              'COTE D\'IVOIRE',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          ListTile(
            title: Text(
              'Langue',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            trailing: Text(
              'FRENCH',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          ListTile(
            title: Text(
              'Version',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '1.0.0',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'À JOUR',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          ListTile(
            leading: const Icon(Icons.headset_mic, color: Colors.green),
            title: const Text('Contactez le support'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EcranSupport()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.grey),
            title: const Text('À propos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EcranAPropos()),
              );
            },
          ),
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseAuth.instance.currentUser == null
                ? null
                : FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .get(),
            builder: (context, snapshot) {
              final role = snapshot.data?.data()?['role'];
              if (role != 'client' && role != 'artisan') {
                return const SizedBox.shrink();
              }
              final estArtisan = role == 'artisan';
              return ListTile(
                leading: const Icon(Icons.qr_code_scanner,
                    color: Colors.blueAccent),
                title: Text(estArtisan
                    ? 'Vérifier un client'
                    : 'Vérifier un artisan'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EcranVerificationIdentifiant(
                        roleAutorise: role.toString(),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // Option Effacer le cache en bas
          const Divider(height: 1, thickness: 1),
          ListTile(
            title: Text(
              'Effacer le cache ($_cacheSize)',
              style: TextStyle(fontSize: 14, color: Colors.red[300]),
            ),
            trailing: _isClearingCache
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                    onPressed: _clearCache,
                  ),
            onTap: _isClearingCache ? null : _clearCache,
          ),
        ],
      ),
    );
  }
}

class EcranAuthentification extends StatefulWidget {
  const EcranAuthentification({super.key});
  @override
  State<EcranAuthentification> createState() => _EcranAuthentificationState();
}

class _EcranAuthentificationState extends State<EcranAuthentification> {
  String _mode = 'connexion';
  String _modeConnexion = 'telephone';
  // Conservé uniquement pour l'ancien bloc de formulaire inatteignable.
  String _roleChoisi = 'client';
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _enChargement = false;
  bool _passwordVisible = false;
  bool _resetPasswordVisible = false;
  bool _resetConfirmationVisible = false;
  final AuthService _authService = AuthService();

  Future<void> _soumettre() async {
    setState(() => _enChargement = true);
    try {
      final numeroFormate = formaterNumeroIvoirien(_telephoneController.text);
      if (numeroFormate == null) {
        throw 'Numéro invalide. Formats acceptés : 01, 05, 07, 25 ou 27 suivis de 8 chiffres.';
      }
      final emailSynthetique = '${numeroFormate.substring(1)}@serviceproci.app';
      await _authService.loginWithEmail(
        emailSynthetique,
        _passwordController.text.trim(),
      );

      User? user = _authService.currentUser;
      await user?.reload();
      user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        final userData = userDoc.data();
        if (userData?['role'] != 'artisan' &&
            userData?['statutVerification'] == 'non_soumis') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const EcranVerificationClient()),
            );
          }
          return;
        }
      }
      await _initNotificationsBackground();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EcranProfil()),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
    }
    if (mounted) setState(() => _enChargement = false);
  }

  Future<String> _envoyerOtpReinitialisation(String numeroFormate) {
    final completer = Completer<String>();
    FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: numeroFormate,
      timeout: const Duration(seconds: 120),
      codeSent: (verificationId, resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );
    return completer.future;
  }

  Future<void> _afficherResetTelephone() async {
    final telephoneController = TextEditingController();
    final codeController = TextEditingController();
    final nouveauMotDePasseController = TextEditingController();
    final confirmationController = TextEditingController();

    final numero = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Réinitialiser par SMS'),
        content: TextField(
          controller: telephoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          decoration: const InputDecoration(
            labelText: 'Numéro de téléphone',
            hintText: '07 XX XX XX XX',
            prefixText: '+225 ',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              final numeroFormate = formaterNumeroIvoirien(telephoneController.text);
              if (numeroFormate == null) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Numéro ivoirien invalide'), backgroundColor: Colors.red),
                );
                return;
              }
              Navigator.pop(context, numeroFormate);
            },
            child: const Text('Envoyer le code'),
          ),
        ],
      ),
    );
    telephoneController.dispose();
    if (numero == null || !mounted) return;

    try {
      final verificationId = await _envoyerOtpReinitialisation(numero);
      if (!mounted) return;
      final codeValide = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Code de vérification'),
          content: TextField(
            controller: codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'Code reçu par SMS'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final credential = PhoneAuthProvider.credential(
                    verificationId: verificationId,
                    smsCode: codeController.text.trim(),
                  );
                  await FirebaseAuth.instance.signInWithCredential(credential);
                  if (context.mounted) Navigator.pop(context, true);
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(e.code == 'invalid-verification-code' ? 'Code incorrect.' : 'Erreur : ${e.code}'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Vérifier'),
            ),
          ],
        ),
      );
      codeController.dispose();
      if (codeValide != true || !mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nouveau mot de passe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nouveauMotDePasseController,
                obscureText: !_resetPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(_resetPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(
                      () => _resetPasswordVisible = !_resetPasswordVisible,
                    ),
                  ),
                ),
              ),
              TextField(
                controller: confirmationController,
                obscureText: !_resetConfirmationVisible,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  suffixIcon: IconButton(
                    icon: Icon(_resetConfirmationVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(
                      () => _resetConfirmationVisible =
                          !_resetConfirmationVisible,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                final nouveauMotDePasse = nouveauMotDePasseController.text;
                if (nouveauMotDePasse.length < 6 || nouveauMotDePasse != confirmationController.text) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(content: Text('Mot de passe invalide ou confirmation différente.'), backgroundColor: Colors.red),
                  );
                  return;
                }
                try {
                  await FirebaseAuth.instance.currentUser!.updatePassword(nouveauMotDePasse);
                  if (context.mounted) Navigator.pop(context);
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Mot de passe mis à jour.')));
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(content: Text('Erreur : ${e.message ?? e.code}'), backgroundColor: Colors.red));
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      );
      nouveauMotDePasseController.dispose();
      confirmationController.dispose();
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d’envoyer le SMS : ${e.message ?? e.code}'), backgroundColor: Colors.red));
    }
  }

  void _afficherBoiteMotDePasseOublie() {
    _afficherResetTelephone();
  }

  Widget _buildTelephoneOnly() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion par téléphone'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 28,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          children: [
            const Icon(Icons.phone_android, size: 80, color: Colors.blueAccent),
            const SizedBox(height: 24),
            const Text(
              'Connectez-vous avec votre numéro',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _telephoneController,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone',
                hintText: '07 XX XX XX XX',
                prefixText: '+225 ',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_android),
                counterText: '',
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: !_passwordVisible,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(_passwordVisible
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () => setState(
                    () => _passwordVisible = !_passwordVisible,
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _afficherResetTelephone,
                child: const Text('Mot de passe oublié ?'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _enChargement ? null : _soumettre,
                child: _enChargement
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Se connecter'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EcranAuthTelephone(),
                  ),
                ),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Créer un compte'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildTelephoneOnly();

    // Ancien formulaire email conservé ci-dessous uniquement pour éviter une
    // modification de portée plus large; il n'est plus atteignable dans l'app.
    const titreAppBar = 'Connexion par téléphone';
    return Scaffold(
      appBar: AppBar(
        title: Text(titreAppBar),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            top: 20.0,
            left: 20.0,
            right: 20.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 30),

              if (false) ...[
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'email', label: Text('Email'), icon: Icon(Icons.email_outlined)),
                    ButtonSegment(value: 'telephone', label: Text('Numéro'), icon: Icon(Icons.phone_android)),
                  ],
                  selected: {_modeConnexion},
                  onSelectionChanged: (selection) => setState(() => _modeConnexion = selection.first),
                ),
                const SizedBox(height: 20),
              ],

              if (_mode == 'inscription') ...[
                const Text(
                  'Je suis un...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _roleChoisi = 'client'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _roleChoisi == 'client'
                                ? Colors.blueAccent
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _roleChoisi == 'client'
                                  ? Colors.blueAccent
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: _roleChoisi == 'client'
                                    ? Colors.white
                                    : Colors.grey,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'CLIENT',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _roleChoisi == 'client'
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _roleChoisi = 'artisan'),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _roleChoisi == 'artisan'
                                ? Colors.blueAccent
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _roleChoisi == 'artisan'
                                  ? Colors.blueAccent
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.handyman_rounded,
                                color: _roleChoisi == 'artisan'
                                    ? Colors.white
                                    : Colors.grey,
                                size: 28,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'ARTISAN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _roleChoisi == 'artisan'
                                      ? Colors.white
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 15),
              ],

              if (_mode != 'connexion' || _modeConnexion == 'email')
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Adresse E-mail',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                )
              else
                TextField(
                  controller: _telephoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '07 XX XX XX XX',
                    prefixText: '+225 ',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_android),
                    counterText: '',
                  ),
                ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: !_passwordVisible,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                  suffixIcon: IconButton(
                    icon: Icon(_passwordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () => setState(
                      () => _passwordVisible = !_passwordVisible,
                    ),
                  ),
                ),
              ),

              if (_mode == 'connexion') ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _afficherBoiteMotDePasseOublie,
                    child: const Text(
                      'Mot de passe oublié ?',
                      style: TextStyle(color: Colors.blueAccent),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _enChargement ? null : _soumettre,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _enChargement
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _mode == 'connexion' ? 'Se connecter' : 'S\'inscrire',
                        ),
                ),
              ),

              const SizedBox(height: 10),

              // ── Séparateur OU ────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'OU',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),

              const SizedBox(height: 10),

              // ── Bouton téléphone ─────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EcranAuthTelephone(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.phone_android,
                    color: Colors.blueAccent,
                  ),
                  label: const Text(
                    'Créer un compte avec un numéro de téléphone',
                    style: TextStyle(color: Colors.blueAccent, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blueAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'La création de compte se fait uniquement par vérification SMS.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EcranSupport extends StatelessWidget {
  const EcranSupport({super.key});

  Future<void> _ouvrirWhatsApp() async {
    final Uri url = Uri.parse('https://wa.me/2250767321816');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Si WhatsApp n'est pas installé, ouvre dans le navigateur
      await launchUrl(
        Uri.parse('https://wa.me/2250767321816'),
        mode: LaunchMode.platformDefault,
      );
    }
  }

  Future<void> _ouvrirEmail() async {
    final Uri url = Uri(
      scheme: 'mailto',
      path: 'contact.serviceproci@gmail.com',
      queryParameters: {'subject': 'Support Service Pro CI'},
    );
    try {
      await launchUrl(url);
    } catch (e) {
      // Si aucun client mail, ouvre Gmail dans le navigateur
      await launchUrl(
        Uri.parse(
          'https://mail.google.com/mail/?view=cm&to=contact.serviceproci@gmail.com',
        ),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.headset_mic, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text(
                'Besoin d\'aide ?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Notre équipe est disponible pour vous aider.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // ── Bouton WhatsApp ──────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _ouvrirWhatsApp,
                  icon: const Icon(Icons.chat),
                  label: const Text(
                    'WhatsApp : +225 07 67 32 18 16',
                    style: TextStyle(fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // ── Bouton Email ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _ouvrirEmail,
                  icon: const Icon(Icons.email),
                  label: const Text(
                    'contact.serviceproci@gmail.com',
                    style: TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EcranAPropos extends StatelessWidget {
  const EcranAPropos({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('À propos'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header bleu
            Container(
              width: double.infinity,
              color: Colors.blueAccent,
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Image.asset('assets/logo.png', height: 80),
                  const SizedBox(height: 10),
                  const Text(
                    'Service Pro CI',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'Version 1.0.0',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'L\'annuaire élite des artisans en Côte d\'Ivoire',
                    style: TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Notre Mission',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Service Pro CI connecte les clients avec des artisans qualifiés et vérifiés en Côte d\'Ivoire. Notre plateforme simplifie la recherche d\'artisans fiables pour tous vos travaux.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                '500+',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              Text(
                                'Artisans',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                '1000+',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              Text(
                                'Utilisateurs',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Column(
                            children: [
                              Text(
                                '14',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                              ),
                              Text(
                                'Métiers',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Nous contacter',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: const Icon(
                      Icons.language,
                      color: Colors.blueAccent,
                    ),
                    title: const Text('Site Web'),
                    subtitle: const Text('www.serviceproci.online'),
                    onTap: () async {
                      final Uri url = Uri.parse(
                        'https://www.serviceproci.online',
                      );
                      if (await canLaunchUrl(url))
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.email, color: Colors.blueAccent),
                    title: const Text('Email'),
                    subtitle: const Text('contact.serviceproci@gmail.com'),
                    onTap: () async {
                      final Uri url = Uri.parse(
                        'mailto:contact.serviceproci@gmail.com',
                      );
                      if (await canLaunchUrl(url)) await launchUrl(url);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.chat, color: Colors.green),
                    title: const Text('WhatsApp'),
                    subtitle: const Text('+225 07 67 32 18 16'),
                    onTap: () async {
                      final Uri url = Uri.parse('https://wa.me/2250767321816');
                      if (await canLaunchUrl(url))
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.privacy_tip,
                      color: Colors.blueAccent,
                    ),
                    title: const Text('Conditions d\'utilisation'),
                    subtitle: const Text('serviceproci.online/cgu'),
                    onTap: () async {
                      final Uri url = Uri.parse(
                        'https://www.serviceproci.online/cgu',
                      );
                      if (await canLaunchUrl(url))
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                    },
                  ),
                  const Divider(),
                  const Center(
                    child: Text(
                      '© 2026 Service Pro CI. Tous droits réservés.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EcranVide extends StatelessWidget {
  final String message;
  const EcranVide({super.key, required this.message});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

class EcranTutoriel extends StatefulWidget {
  const EcranTutoriel({super.key});
  @override
  State<EcranTutoriel> createState() => _EcranTutorielState();
}

class _EcranTutorielState extends State<EcranTutoriel> {
  final PageController _pageController = PageController();
  int _pageActuelle = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNotificationsBackground();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _pageActuelle = index),
                children: [
                  _construirePage(
                    Icons.search,
                    "Trouvez un artisan",
                    "Simple et rapide.",
                  ),
                  _construirePage(
                    Icons.work_outline,
                    "Proposez vos services",
                    "Devenez Premium !",
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: ElevatedButton(
                onPressed: () {
                  if (_pageActuelle == 1) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EcranAccueil(),
                      ),
                    );
                  } else {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Text(_pageActuelle == 1 ? "Commencer" : "Suivant"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construirePage(IconData icone, String titre, String desc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icone, size: 100, color: Colors.blueAccent),
        const SizedBox(height: 20),
        Text(
          titre,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text(desc, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

// ==========================================
// ÉCRAN : ASSISTANT IA
// ==========================================
class EcranAssistantIA extends StatefulWidget {
  const EcranAssistantIA({super.key});

  @override
  State<EcranAssistantIA> createState() => _EcranAssistantIAState();
}

class _EcranAssistantIAState extends State<EcranAssistantIA> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _enChargement = false;

  Future<void> _envoyerMessage(String texte) async {
  if (texte.trim().isEmpty) return;
  setState(() {
    _messages.add({'role': 'user', 'text': texte});
    _enChargement = true;
  });
  _controller.clear();

  try {
    final callable = FirebaseFunctions.instance.httpsCallable('chatWithClaude');
    final result = await callable.call({'message': texte});
    final reponse = result.data['reply'] ?? 'Erreur de réponse.';

    setState(() {
      _messages.add({'role': 'bot', 'text': reponse});
      _enChargement = false;
    });
  } catch (e) {
    setState(() {
      _messages.add({'role': 'bot', 'text': 'Erreur : impossible de contacter l\'assistant.'});
      _enChargement = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Assistant IA'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF1565C0) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isUser ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_enChargement)
            const Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(color: Color(0xFF1565C0)),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Posez votre question...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _envoyerMessage(_controller.text),
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Color(0xFF1565C0),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
