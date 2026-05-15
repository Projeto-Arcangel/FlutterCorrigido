const functionsV1 = require("firebase-functions/v1");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

const { generateQuestionsWithFallback } = require("./openrouter");

admin.initializeApp();

const openRouterApiKey = defineSecret("OPENROUTER_API_KEY");

// ─── Trigger legado (preservado) ──────────────────────────────────────
exports.onUserDeleted = functionsV1.auth.user().onDelete(async (user) => {
  const firestore = admin.firestore();
  await firestore.collection("Users").doc(user.uid).delete();
});

// ─── Geração de questões com IA (OpenRouter) ──────────────────────────
exports.generateQuestionsAI = onCall(
  {
    secrets: [openRouterApiKey],
    region: "southamerica-east1",
    timeoutSeconds: 90,
    cors: true,
  },
  async (request) => {
    // 1. Auth obrigatória
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Você precisa estar autenticado para gerar questões.",
      );
    }

    const uid = request.auth.uid;

    // 2. Só professores podem chamar
    const userSnap = await admin
      .firestore()
      .collection("Users")
      .doc(uid)
      .get();

    const role = userSnap.data()?.role;
    if (role !== "teacher") {
      throw new HttpsError(
        "permission-denied",
        "Apenas professores podem gerar questões com IA.",
      );
    }

    // 3. Validação superficial dos inputs (a fundo é no openrouter.js)
    const data = request.data || {};
    const {
      subject,
      topic,
      difficulty,
      quantity,
      description,
      modelKey,
    } = data;

    if (!topic || typeof topic !== "string") {
      throw new HttpsError("invalid-argument", "O tema é obrigatório.");
    }

    // 4. Chama o orquestrador com fallback
    try {
      const result = await generateQuestionsWithFallback(
        {
          subject,
          topic,
          difficulty,
          quantity: Number(quantity),
          description,
          modelKey,
        },
        openRouterApiKey.value(),
      );

      logger.info(
        `[ia_quiz] Geradas ${result.questions.length} questões com ${result.modelUsed} para ${uid}.`,
      );

      return result;
    } catch (err) {
      logger.error(`[ia_quiz] Falha na geração para ${uid}: ${err.message}`);
      throw new HttpsError(
        "internal",
        err.message || "Falha ao gerar questões.",
        { attempts: err.attempts },
      );
    }
  },
);
