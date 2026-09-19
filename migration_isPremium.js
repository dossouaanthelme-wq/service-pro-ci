/**
 * Script de migration : ajoute isPremium et premiumExpiresAt
 * à tous les artisans existants qui n'ont pas encore ces champs.
 *
 * UTILISATION :
 * 1. Place ce fichier dans le dossier racine de ton projet (E:\service_pro_ci)
 * 2. Télécharge ta clé de service Firebase :
 *    Console Firebase > Paramètres du projet > Comptes de service
 *    > "Générer une nouvelle clé privée" > enregistre le fichier sous le nom
 *    "serviceAccountKey.json" dans le même dossier que ce script.
 *    ⚠️ NE JAMAIS committer ce fichier sur GitHub (ajoute-le au .gitignore)
 * 3. Installe la dépendance si besoin :
 *    npm install firebase-admin
 *    (nécessite firebase-admin v12 ou plus récent, API modulaire)
 * 4. Exécute le script :
 *    node migration_isPremium.js
 */

const { initializeApp, cert } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const serviceAccount = require("./serviceAccountKey.json");

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

async function migrerArtisans() {
  console.log("Lecture de la collection 'artisans'...");

  const snapshot = await db.collection("artisans").get();

  if (snapshot.empty) {
    console.log("Aucun artisan trouvé dans la collection.");
    return;
  }

  console.log(`${snapshot.size} artisan(s) trouvé(s). Vérification en cours...`);

  let batch = db.batch();
  let compteurMisAJour = 0;
  let compteurDansBatch = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();

    // On ne touche qu'aux documents où isPremium n'existe pas encore
    if (data.isPremium === undefined) {
      batch.update(doc.ref, {
        isPremium: false,
        premiumExpiresAt: null,
      });
      compteurMisAJour++;
      compteurDansBatch++;

      // Firestore limite un batch à 500 opérations max
      if (compteurDansBatch === 450) {
        await batch.commit();
        console.log(`Batch intermédiaire envoyé (${compteurMisAJour} au total)...`);
        batch = db.batch();
        compteurDansBatch = 0;
      }
    }
  }

  // Envoie le dernier batch s'il reste des opérations en attente
  if (compteurDansBatch > 0) {
    await batch.commit();
  }

  console.log("---------------------------------------------");
  console.log(`Migration terminée : ${compteurMisAJour} document(s) mis à jour.`);
  console.log(`${snapshot.size - compteurMisAJour} document(s) avaient déjà le champ isPremium (non touchés).`);
  console.log("---------------------------------------------");
}

migrerArtisans()
  .then(() => {
    console.log("Script terminé avec succès.");
    process.exit(0);
  })
  .catch((err) => {
    console.error("Erreur pendant la migration :", err);
    process.exit(1);
  });
