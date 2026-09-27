const {
  onDocumentCreated,
  onDocumentUpdated,
} = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const axios = require("axios");
const crypto = require("crypto");

admin.initializeApp();

// ── OTP SMS via LeTexto (Orange / Moov) ─────────────────────────────────
const LETEXTO_TOKEN = defineSecret("LETEXTO_TOKEN");
const LETEXTO_SENDER = "ServicePro";
const LETEXTO_URL = "https://apis.letexto.com/v1/messages/send";
const OTP_DUREE_MS = 5 * 60 * 1000;

exports.verifierNumeroExistant = onCall(
  async (request) => {
    const telephone = request.data?.telephone;
    if (typeof telephone !== "string") {
      throw new HttpsError("invalid-argument", "Numéro de téléphone requis");
    }

    const comptesExistants = await admin.firestore()
      .collection("users")
      .where("telephone", "==", telephone)
      .limit(1)
      .get();

    if (comptesExistants.empty) {
      return { compteExistant: false };
    }

    const emailSynthetique = comptesExistants.docs[0].data().emailSynthetique;
    return {
      compteExistant:
        typeof emailSynthetique === "string" && emailSynthetique.length > 0,
    };
  }
);

exports.genererEtEnvoyerOtpLeTexto = onCall(
  { secrets: [LETEXTO_TOKEN] },
  async (request) => {
    const { telephone } = request.data;

    if (!telephone || !/^\+225\d{10}$/.test(telephone)) {
      throw new HttpsError("invalid-argument", "Numéro invalide. Format attendu : +225XXXXXXXXXX");
    }

    const otpRef = admin.firestore().collection("otp_codes").doc(telephone);
    const otpDoc = await otpRef.get();

    if (otpDoc.exists) {
      const existant = otpDoc.data();
      const depuisDernierEnvoi = Date.now() - (existant.lastSentAt || 0);
      if (depuisDernierEnvoi < 60 * 1000) {
        throw new HttpsError("resource-exhausted", "Veuillez patienter avant de redemander un code.");
      }
    }

    const aujourdHui = new Date().toISOString().slice(0, 10);
    const compteurRef = admin.firestore()
      .collection("otp_daily_count")
      .doc(`${telephone}_${aujourdHui}`);
    const compteurDoc = await compteurRef.get();
    const envoisAujourdHui = compteurDoc.exists ? (compteurDoc.data().count || 0) : 0;

    if (envoisAujourdHui >= 5) {
      throw new HttpsError("resource-exhausted", "Limite quotidienne de codes atteinte. Réessayez demain.");
    }

    const code = String(crypto.randomInt(100000, 999999));
    const expiresAt = Date.now() + OTP_DUREE_MS;

    await otpRef.set({
      code,
      expiresAt,
      attempts: 0,
      lastSentAt: Date.now(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await compteurRef.set(
      { count: admin.firestore.FieldValue.increment(1) },
      { merge: true }
    );

    const numeroSansPlus = telephone.replace("+", "");

    try {
      const response = await axios.post(
        LETEXTO_URL,
        {
          to: numeroSansPlus,
          content: `Service Pro CI - Code : ${code}. Valable 5 minutes.`,
          from: LETEXTO_SENDER,
        },
        {
          headers: {
            "Authorization": `Bearer ${LETEXTO_TOKEN.value()}`,
            "Content-Type": "application/json",
          },
        }
      );

      console.log("✅ SMS LeTexto envoyé à", numeroSansPlus, response.data);
      return { success: true };
    } catch (e) {
      console.error("❌ Erreur SMS LeTexto :", e.response?.data || e.message);
      throw new HttpsError("internal", "Erreur envoi SMS : " + JSON.stringify(e.response?.data || e.message));
    }
  }
);

exports.verifierOtpLeTexto = onCall(
  {},
  async (request) => {
    const { telephone, code } = request.data;

    if (!telephone || !code) {
      throw new HttpsError("invalid-argument", "Numéro et code requis");
    }

    const docRef = admin.firestore().collection("otp_codes").doc(telephone);
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new HttpsError("invalid-argument", "Code introuvable ou déjà utilisé. Recommencez.");
    }

    const data = doc.data();

    if (Date.now() > data.expiresAt) {
      await docRef.delete();
      throw new HttpsError("invalid-argument", "Code expiré. Recommencez.");
    }

    if (data.code !== code) {
      const tentatives = (data.attempts || 0) + 1;
      if (tentatives >= 5) {
        await docRef.delete();
        throw new HttpsError("resource-exhausted", "Trop de tentatives incorrectes. Demandez un nouveau code.");
      }
      await docRef.update({ attempts: tentatives });
      throw new HttpsError("invalid-argument", "Code incorrect.");
    }

    await docRef.delete();

    let userRecord;
    try {
      userRecord = await admin.auth().getUserByPhoneNumber(telephone);
    } catch (e) {
      userRecord = await admin.auth().createUser({ phoneNumber: telephone });
    }

    const customToken = await admin.auth().createCustomToken(userRecord.uid);
    return { customToken };
  }
);

// ── Notification FCM ──────────────────────────────────────────────────
exports.envoyerNotificationFCM = onDocumentCreated(
  "notifications/{notifId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return null;

    const targetUserId = data.targetUserId;
    if (!targetUserId) return null;

    // Recherche du token FCM dans artisans puis clients
    let fcmToken   = null;
    let collection = null;

    const artisanDoc = await admin.firestore()
      .collection("artisans")
      .doc(targetUserId)
      .get();

    if (artisanDoc.exists) {
      fcmToken   = artisanDoc.data()?.fcmToken ?? null;
      collection = "artisans";
    } else {
      const clientDoc = await admin.firestore()
        .collection("clients")
        .doc(targetUserId)
        .get();
      fcmToken   = clientDoc.data()?.fcmToken ?? null;
      collection = "clients";
      if (!fcmToken) {
        const userDoc = await admin.firestore()
          .collection("users")
          .doc(targetUserId)
          .get();
        fcmToken = userDoc.data()?.fcmToken ?? null;
        collection = "users";
      }
    }

    if (!fcmToken) {
      console.warn("⚠️ Aucun token FCM pour userId :", targetUserId);
      return null;
    }

    const estVerification = data.type === "verification_identite";
    const message = {
      token: fcmToken,
      notification: {
        title: estVerification ? data.title : "💬 Nouveau message !",
        body:  estVerification
          ? data.body
          : `${data.userName} vous a laissé un commentaire`,
      },
      android: {
        notification: {
          channelId: "service_pro_channel",
          priority:  "high",
          sound:     "default",
        },
      },
      data: {
        type:      estVerification ? "verification_identite" : "commentaire",
        artisanId: targetUserId,
      },
    };

    try {
      await admin.messaging().send(message);
      console.log("✅ Notification envoyée à", targetUserId);
    } catch (e) {
      if (e.code === "messaging/registration-token-not-registered") {
        console.warn("🗑️ Token expiré, suppression pour :", targetUserId);
        await admin.firestore()
          .collection(collection)
          .doc(targetUserId)
          .update({ fcmToken: admin.firestore.FieldValue.delete() });
      } else {
        console.error("❌ Erreur notification :", e);
      }
    }

    return null;
  }
);

// ── Notification de changement de statut KYC artisan ────────────────
exports.notifierVerificationArtisan = onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const avant = event.data?.before.data();
    const apres = event.data?.after.data();
    if (!avant || !apres || apres.role !== "artisan") return null;

    const ancienStatut = avant.statutVerification;
    const nouveauStatut = apres.statutVerification;
    if (
      ancienStatut !== "en_attente" ||
      !["valide", "rejete"].includes(nouveauStatut)
    ) {
      return null;
    }

    const uid = event.params.uid;
    const estValide = nouveauStatut === "valide";
    await admin.firestore().collection("notifications").add({
      targetUserId: uid,
      userId: uid,
      type: "verification_identite",
      title: estValide ? "Identité vérifiée" : "Vérification à corriger",
      body: estValide
        ? "Votre identité a été validée."
        : "Votre vérification a été rejetée. Consultez le motif et soumettez de nouveaux documents.",
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
    return null;
  }
);
// ── GeniusPay : création du lien de paiement Premium ────────────────────
const GENIUSPAY_API_KEY = defineSecret("GENIUSPAY_API_KEY");
const GENIUSPAY_API_SECRET = defineSecret("GENIUSPAY_API_SECRET");

exports.creerLienPaiementPremium = onCall(
  { secrets: [GENIUSPAY_API_KEY, GENIUSPAY_API_SECRET] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Connexion requise.");
    }

    const docId = request.data?.docId;
    if (!docId) throw new HttpsError("invalid-argument", "docId requis");

    if (docId !== request.auth.uid) {
      throw new HttpsError(
        "permission-denied",
        "Vous ne pouvez créer un paiement Premium que pour votre propre compte."
      );
    }

    try {
      const artisanSnap = await admin.firestore().collection("artisans").doc(docId).get();

      if (!artisanSnap.exists) {
        throw new HttpsError("not-found", "Profil artisan introuvable.");
      }

      const userSnap = await admin.firestore().collection("users").doc(docId).get();
      if (!userSnap.exists || userSnap.data()?.role !== "artisan") {
        throw new HttpsError("permission-denied", "Ce compte n'est pas un profil artisan.");
      }

      const telephone = artisanSnap.data()?.telephone;
      const reference = `${docId}_${Date.now()}`;
      await admin.firestore().collection("pending_payments").doc(reference).set({
        uid: request.auth.uid,
        docId,
        montant: 2000,
        devise: "XOF",
        statut: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const response = await axios.post(
        "https://geniuspay.ci/api/v1/merchant/payments",
        {
          amount: 2000,
          description: "Abonnement Premium Artisan (30 jours)",
          ...(telephone ? { customer: { phone: telephone } } : {}),
          metadata: { docId, reference },
          success_url: "https://service-pro-ci.web.app/premium-success.html",
          error_url: "https://service-pro-ci.web.app/premium-error.html",
        },
        {
          headers: {
            "X-API-Key": GENIUSPAY_API_KEY.value(),
            "X-API-Secret": GENIUSPAY_API_SECRET.value(),
            "Content-Type": "application/json",
          },
        }
      );

      const checkoutUrl = response.data?.data?.checkout_url;
      if (!checkoutUrl) throw new HttpsError("internal", "Réponse GeniusPay invalide");

      try {
        const checkoutHostname = new URL(checkoutUrl).hostname;
        if (!checkoutHostname.endsWith("geniuspay.ci")) {
          throw new HttpsError("internal", "URL de paiement invalide");
        }
      } catch (e) {
        if (e instanceof HttpsError) throw e;
        throw new HttpsError("internal", "URL de paiement invalide");
      }

      return { checkout_url: checkoutUrl };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("❌ Erreur création paiement GeniusPay :", e.response?.data || e.message);
      throw new HttpsError("internal", "Erreur création lien de paiement : " + JSON.stringify(e.response?.data || e.message));
    }
  }
);

// ── Webhook GeniusPay (activation premium) ──────────────────────────────
const GENIUSPAY_WEBHOOK_SECRET = defineSecret("GENIUSPAY_WEBHOOK_SECRET");

exports.geniuspayWebhook = onRequest(
  { secrets: [GENIUSPAY_WEBHOOK_SECRET] },
  async (req, res) => {
    const signature = req.get("X-Webhook-Signature");
    const timestamp = req.get("X-Webhook-Timestamp");
    if (!signature || !timestamp) {
      return res.status(401).send("Missing signature");
    }

    const now = Math.floor(Date.now() / 1000);
    if (Math.abs(now - Number(timestamp)) > 300) {
      return res.status(400).send("Timestamp expired");
    }

    const rawBody = req.rawBody ? req.rawBody.toString() : JSON.stringify(req.body);
    const expectedSignature = crypto
      .createHmac("sha256", GENIUSPAY_WEBHOOK_SECRET.value())
      .update(`${timestamp}.${rawBody}`)
      .digest("hex");

    const signatureBuffer = Buffer.from(signature);
    const expectedBuffer = Buffer.from(expectedSignature);
    const signatureValide =
      signatureBuffer.length === expectedBuffer.length &&
      crypto.timingSafeEqual(signatureBuffer, expectedBuffer);

    if (!signatureValide) {
      return res.status(401).send("Invalid signature");
    }

    const event = req.body;
    if (event.event === "payment.success" && event.data?.status === "completed") {
      const docId = event.data.metadata?.docId;
      const reference = event.data.metadata?.reference;
      if (!docId || !reference) return res.status(400).send("Missing payment metadata");

      const amount = event.data.amount;
      const devise = event.data.currency ?? event.data.devise;
      if (amount !== 2000 || devise !== "XOF") {
        return res.status(400).send("Invalid payment amount or currency");
      }

      const db = admin.firestore();
      const pendingPaymentRef = db.collection("pending_payments").doc(reference);
      const pendingPayment = await pendingPaymentRef.get();
      if (!pendingPayment.exists || pendingPayment.data()?.statut === "completed") {
        return res.status(200).send("OK");
      }

      const expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 30);

      const paiementActive = await db.runTransaction(async (transaction) => {
        const pendingSnapshot = await transaction.get(pendingPaymentRef);
        if (!pendingSnapshot.exists || pendingSnapshot.data()?.statut === "completed") {
          return false;
        }

        const pendingData = pendingSnapshot.data();
        if (pendingData?.docId !== docId) {
          throw new Error("Payment metadata mismatch");
        }

        const artisanRef = db.collection("artisans").doc(docId);
        transaction.update(pendingPaymentRef, {
          statut: "completed",
        });
        transaction.update(artisanRef, {
          isPremium: true,
          premiumExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
          rappelEnvoye: false,
        });
        return true;
      });

      if (!paiementActive) {
        return res.status(200).send("OK");
      }

      try {
        const artisanDoc = await admin.firestore().collection("artisans").doc(docId).get();
        const fcmToken = artisanDoc.data()?.fcmToken;
        if (fcmToken) {
          await admin.messaging().send({
            token: fcmToken,
            notification: {
              title: "🎉 Abonnement Premium activé !",
              body: "Votre abonnement Premium est actif pour 30 jours. Profitez de tous les avantages dès maintenant.",
            },
            android: {
              notification: {
                channelId: "service_pro_channel",
                priority: "high",
                sound: "default",
              },
            },
            data: {
              type: "premium_active",
              artisanId: docId,
            },
          });
        }
      } catch (e) {
        console.error("❌ Erreur notification Premium :", e);
      }
    }

    res.status(200).send("OK");
  }
);

exports.checkPremiumExpiration = onSchedule("every 24 hours", async () => {
  const now = admin.firestore.Timestamp.now();
  const snapshot = await admin.firestore()
    .collection("artisans")
    .where("isPremium", "==", true)
    .where("premiumExpiresAt", "<", now)
    .get();

  if (snapshot.empty) return null;

  const batch = admin.firestore().batch();
  snapshot.docs.forEach((doc) => {
    batch.update(doc.ref, { isPremium: false });
  });
  await batch.commit();

  return null;
});

exports.envoyerRappelsPremium = onSchedule("every 24 hours", async () => {
  const now = Date.now();
  const dans5Jours = now + 5 * 24 * 60 * 60 * 1000;

  const snapshot = await admin.firestore()
    .collection("artisans")
    .where("isPremium", "==", true)
    .get();

  if (snapshot.empty) return null;

  const batch = admin.firestore().batch();
  let aEcrire = false;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const expiresAt = data.premiumExpiresAt?.toMillis?.();
    if (!expiresAt) continue;

    if (expiresAt > now && expiresAt <= dans5Jours && data.rappelEnvoye !== true) {
      const notifRef = admin.firestore().collection("notifications").doc();
      batch.set(notifRef, {
        type: "rappel_premium",
        artisanId: doc.id,
        targetUserId: doc.id,
        userId: doc.id,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      batch.update(doc.ref, { rappelEnvoye: true });
      aEcrire = true;

      if (data.fcmToken) {
        admin.messaging().send({
          token: data.fcmToken,
          notification: {
            title: "⏳ Votre abonnement Premium expire bientôt",
            body: "Il vous reste 5 jours avant la fin de votre abonnement Premium. Pensez à le renouveler.",
          },
          android: {
            notification: {
              channelId: "service_pro_channel",
              priority: "high",
              sound: "default",
            },
          },
          data: { type: "rappel_premium", artisanId: doc.id },
        }).catch((e) => console.error("Erreur push rappel premium :", e));
      }
    }
  }

  if (aEcrire) await batch.commit();
  return null;
});