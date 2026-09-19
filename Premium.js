[1mdiff --git a/lib/verify_email_page.dart b/lib/verify_email_page.dart[m
[1mindex 52fc117..ac9dd85 100644[m
[1m--- a/lib/verify_email_page.dart[m
[1m+++ b/lib/verify_email_page.dart[m
[36m@@ -1,10 +1,16 @@[m
 import 'package:flutter/material.dart';[m
 import 'package:firebase_auth/firebase_auth.dart';[m
[31m-import 'main.dart'; // Pour accéder à EcranAccueil[m
[32m+[m[32mimport 'main.dart';[m
 [m
 class VerifyEmailPage extends StatefulWidget {[m
   final String email;[m
[31m-  const VerifyEmailPage({super.key, required this.email});[m
[32m+[m[32m  final String role; // ✅ NOUVEAU : 'client' ou 'artisan'[m
[32m+[m
[32m+[m[32m  const VerifyEmailPage({[m
[32m+[m[32m    super.key,[m
[32m+[m[32m    required this.email,[m
[32m+[m[32m    this.role = 'client', // ✅ Par défaut client[m
[32m+[m[32m  });[m
 [m
   @override[m
   State<VerifyEmailPage> createState() => _VerifyEmailPageState();[m
[36m@@ -18,29 +24,75 @@[m [mclass _VerifyEmailPageState extends State<VerifyEmailPage> {[m
     try {[m
       await FirebaseAuth.instance.currentUser!.reload();[m
       User? user = FirebaseAuth.instance.currentUser;[m
[32m+[m
       if (user != null && user.emailVerified) {[m
         if (mounted) {[m
[31m-          Navigator.pushReplacement([m
[31m-            context,[m
[31m-            MaterialPageRoute(builder: (context) => const EcranAccueil()),[m
[31m-          );[m
[32m+[m[32m          // ✅ Redirection selon le rôle[m
[32m+[m[32m          if (widget.role == 'artisan') {[m
[32m+[m[32m            // L'artisan va créer sa fiche[m
[32m+[m[32m            Navigator.pushReplacement([m
[32m+[m[32m              context,[m
[32m+[m[32m              MaterialPageRoute([m
[32m+[m[32m                builder: (context) => const EcranProfessionnel(),[m
[32m+[m[32m              ),[m
[32m+[m[32m            );[m
[32m+[m[32m          } else {[m
[32m+[m[32m            // Le client va à l'accueil[m
[32m+[m[32m            Navigator.pushReplacement([m
[32m+[m[32m              context,[m
[32m+[m[32m              MaterialPageRoute([m
[32m+[m[32m                builder: (context) => const EcranAccueil(),[m
[32m+[m[32m              ),[m
[32m+[m[32m            );[m
[32m+[m[32m          }[m
         }[m
       } else {[m
[32m+[m[32m        if (mounted) {[m
[32m+[m[32m          ScaffoldMessenger.of(context).showSnackBar([m
[32m+[m[32m            const SnackBar([m
[32m+[m[32m              content: Text('Votre e-mail n\'est pas encore vérifié. Vérifiez votre boîte mail.'),[m
[32m+[m[32m              backgroundColor: Colors.orange,[m
[32m+[m[32m              behavior: SnackBarBehavior.floating,[m
[32m+[m[32m            ),[m
[32m+[m[32m          );[m
[32m+[m[32m        }[m
[32m+[m[32m      }[m
[32m+[m[32m    } catch (e) {[m
[32m+[m[32m      if (mounted) {[m
         ScaffoldMessenger.of(context).showSnackBar([m
[31m-          const SnackBar(content: Text('Votre e-mail n\'est pas encore vérifié. Vérifiez votre boîte mail.')),[m
[32m+[m[32m          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),[m
         );[m
       }[m
[31m-    } catch (e) {[m
[31m-      ScaffoldMessenger.of(context).showSnackBar([m
[31m-        SnackBar(content: Text('Erreur : $e')),[m
[31m-      );[m
     } finally {[m
       if (mounted) setState(() => _isLoading = false);[m
     }[m
   }[m
 [m
[32m+[m[32m  Future<void> _renvoyerEmail() async {[m
[32m+[m[32m    try {[m
[32m+[m[32m      await FirebaseAuth.instance.currentUser!.sendEmailVerification();[m
[32m+[m[32m      if (mounted) {[m
[32m+[m[32m        ScaffoldMessenger.of(context).showSnackBar([m
[32m+[m[32m          const SnackBar([m
[32m+[m[32m            content: Text('Email de vérification renvoyé !'),[m
[32m+[m[32m            backgroundColor: Colors.green,[m
[32m+[m[32m            behavior: SnackBarBehavior.floating,[m
[32m+[m[32m          ),[m
[32m+[m[32m        );[m
[32m+[m[32m      }[m
[32m+[m[32m    } catch (e) {[m
[32m+[m[32m      if (mounted) {[m
[32m+[m[32m        ScaffoldMessenger.of(context).showSnackBar([m
[32m+[m[32m          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),[m
[32m+[m[32m        );[m
[32m+[m[32m      }[m
[32m+[m[32m    }[m
[32m+[m[32m  }[m
[32m+[m
   @override[m
   Widget build(BuildContext context) {[m
[32m+[m[32m    final bool estArtisan = widget.role == 'artisan';[m
[32m+[m
     return Scaffold([m
       appBar: AppBar([m
         title: const Text('Vérification de l\'e-mail'),[m
[36m@@ -52,33 +104,105 @@[m [mclass _VerifyEmailPageState extends State<VerifyEmailPage> {[m
         child: Column([m
           mainAxisAlignment: MainAxisAlignment.center,[m
           children: [[m
[31m-            const Icon(Icons.email, size: 100, color: Colors.blueAccent),[m
[32m+[m[32m            // Icône selon le rôle[m
[32m+[m[32m            Container([m
[32m+[m[32m              width: 100,[m
[32m+[m[32m              height: 100,[m
[32m+[m[32m              decoration: BoxDecoration([m
[32m+[m[32m                color: Colors.blueAccent.withOpacity(0.1),[m
[32m+[m[32m                shape: BoxShape.circle,[m
[32m+[m[32m              ),[m
[32m+[m[32m              child: Icon([m
[32m+[m[32m                estArtisan ? Icons.handyman_rounded : Icons.email_rounded,[m
[32m+[m[32m                size: 55,[m
[32m+[m[32m                color: Colors.blueAccent,[m
[32m+[m[32m              ),[m
[32m+[m[32m            ),[m
[32m+[m[32m            const SizedBox(height: 24),[m
[32m+[m
[32m+[m[32m            // Badge rôle[m
[32m+[m[32m            Container([m
[32m+[m[32m              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),[m
[32m+[m[32m              decoration: BoxDecoration([m
[32m+[m[32m                color: estArtisan ? Colors.amber.shade100 : Colors.blue.shade50,[m
[32m+[m[32m                borderRadius: BorderRadius.circular(20),[m
[32m+[m[32m                border: Border.all([m
[32m+[m[32m                  color: estArtisan ? Colors.amber : Colors.blueAccent.withOpacity(0.3),[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m              child: Text([m
[32m+[m[32m                estArtisan ? '🔧 Inscription Artisan' : '👤 Inscription Client',[m
[32m+[m[32m                style: TextStyle([m
[32m+[m[32m                  fontWeight: FontWeight.bold,[m
[32m+[m[32m                  color: estArtisan ? Colors.amber.shade800 : Colors.blueAccent,[m
[32m+[m[32m                  fontSize: 14,[m
[32m+[m[32m                ),[m
[32m+[m[32m              ),[m
[32m+[m[32m            ),[m
[32m+[m
             const SizedBox(height: 20),[m
[32m+[m
             Text([m
               'Un e-mail de validation a été envoyé à ${widget.email}.',[m
               textAlign: TextAlign.center,[m
[31m-              style: const TextStyle(fontSize: 18),[m
[32m+[m[32m              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),[m
             ),[m
             const SizedBox(height: 10),[m
[31m-            const Text([m
[31m-              'Veuillez vérifier votre boîte mail et cliquer sur le lien de validation.',[m
[31m-              textAlign: TextAlign.center,[m
[31m-            ),[m
[32m+[m[32m            Text([m
[32m+[m[32m  estArtisan[m
[32m+[m[32m      ? 'Après vérification, vous pourrez créer votre fiche artisan.'[m
[32m+[m[32m      : 'Vérifiez votre boîte mail et cliquez sur le lien de validation.',[m
[32m+[m[32m  textAlign: TextAlign.center,[m
[32m+[m[32m  style: const TextStyle(color: Colors.grey, fontSize: 14),[m
[32m+[m[32m),[m
[32m+[m[32mconst SizedBox(height: 8),[m
[32m+[m[32m// ✅ NOUVEAU : mention spams[m
[32m+[m[32mRow([m
[32m+[m[32m  mainAxisAlignment: MainAxisAlignment.center,[m
[32m+[m[32m  children: [[m
[32m+[m[32m    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),[m
[32m+[m[32m    const SizedBox(width: 5),[m
[32m+[m[32m    const Flexible([m
[32m+[m[32m      child: Text([m
[32m+[m[32m        'Veillez également à vérifier vos spams, le mail peut s\'y trouver.',[m
[32m+[m[32m        textAlign: TextAlign.center,[m
[32m+[m[32m        style: TextStyle(color: Colors.orange, fontSize: 12),[m
[32m+[m[32m      ),[m
[32m+[m[32m    ),[m
[32m+[m[32m  ],[m
[32m+[m[32m),[m
[32m+[m
             const SizedBox(height: 40),[m
[32m+[m
[32m+[m[32m            // Bouton principal[m
             SizedBox([m
               width: double.infinity,[m
[31m-              height: 50,[m
[31m-              child: ElevatedButton([m
[32m+[m[32m              height: 52,[m
[32m+[m[32m              child: ElevatedButton.icon([m
                 onPressed: _isLoading ? null : _checkEmailVerified,[m
[32m+[m[32m                icon: const Icon(Icons.check_circle_outline),[m
[32m+[m[32m                label: _isLoading[m
[32m+[m[32m                    ? const CircularProgressIndicator(color: Colors.white)[m
[32m+[m[32m                    : const Text('J\'ai vérifié mon mail',[m
[32m+[m[32m                        style: TextStyle(fontSize: 16)),[m
                 style: ElevatedButton.styleFrom([m
                   backgroundColor: Colors.blueAccent,[m
                   foregroundColor: Colors.white,[m
[32m+[m[32m                  shape: RoundedRectangleBorder([m
[32m+[m[32m                      borderRadius: BorderRadius.circular(12)),[m
                 ),[m
[31m-                child: _isLoading[m
[31m-                    ? const CircularProgressIndicator(color: Colors.white)[m
[31m-                    : const Text('J\'ai vérifié mon mail'),[m
               ),[m
             ),[m
[32m+[m
[32m+[m[32m            const SizedBox(height: 16),[m
[32m+[m
[32m+[m[32m            // Bouton renvoyer email[m
[32m+[m[32m            TextButton.icon([m
[32m+[m[32m              onPressed: _renvoyerEmail,[m
[32m+[m[32m              icon: const Icon(Icons.refresh, size: 18),[m
[32m+[m[32m              label: const Text('Renvoyer l\'email de vérification'),[m
[32m+[m[32m              style: TextButton.styleFrom(foregroundColor: Colors.grey),[m
[32m+[m[32m            ),[m
           ],[m
         ),[m
       ),[m
