const {onRequest} = require("firebase-functions/v2/https");
const {getApps, initializeApp} = require("firebase-admin/app");
const {getAuth} = require("firebase-admin/auth");
const {FieldValue, getFirestore, Timestamp} = require("firebase-admin/firestore");

if (getApps().length === 0) initializeApp();

const GOOGLE_OAUTH_CLIENT_ID =
  "101861330698-s5r9c8rlm4jf99thqb0cth6co3v7854a.apps.googleusercontent.com";

exports.exchangeGoogleOAuthCode = onRequest(
  {
    region: "asia-northeast3",
    secrets: ["GOOGLE_OAUTH_CLIENT_SECRET"],
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.set("Allow", "POST").status(405).json({error: "method_not_allowed"});
      return;
    }

    const {code, codeVerifier, redirectUri} = request.body || {};
    const validRedirect =
      typeof redirectUri === "string" &&
      /^http:\/\/127\.0\.0\.1:\d{1,5}\/?$/.test(redirectUri);
    if (
      typeof code !== "string" ||
      typeof codeVerifier !== "string" ||
      codeVerifier.length < 43 ||
      !validRedirect
    ) {
      response.status(400).json({error: "invalid_request"});
      return;
    }

    const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
      method: "POST",
      headers: {"Content-Type": "application/x-www-form-urlencoded"},
      body: new URLSearchParams({
        client_id: GOOGLE_OAUTH_CLIENT_ID,
        client_secret: process.env.GOOGLE_OAUTH_CLIENT_SECRET,
        code,
        code_verifier: codeVerifier,
        grant_type: "authorization_code",
        redirect_uri: redirectUri,
      }),
    });

    const payload = await tokenResponse.json();
    if (!tokenResponse.ok) {
      console.warn("Google OAuth token exchange rejected", {
        status: tokenResponse.status,
        error: payload.error,
        errorDescription: payload.error_description,
      });
      response.status(tokenResponse.status).json({
        error: payload.error || "token_exchange_failed",
        error_description: payload.error_description,
      });
      return;
    }

    response.status(200).json({
      id_token: payload.id_token,
      access_token: payload.access_token,
      expires_in: payload.expires_in,
    });
  },
);

const PRO_ENTITLEMENTS = new Set(["pro", "chalstock Pro"]);
const CLOUD_ENTITLEMENTS = new Set(["cloud_backup"]);
const ACTIVE_EVENT_TYPES = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "NON_RENEWING_PURCHASE",
  "SUBSCRIPTION_EXTENDED",
  "REFUND_REVERSED",
]);

exports.revenueCatWebhook = onRequest(
  {
    region: "asia-northeast3",
    secrets: ["REVENUECAT_WEBHOOK_AUTH"],
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.set("Allow", "POST").status(405).json({error: "method_not_allowed"});
      return;
    }
    if (request.get("authorization") !== process.env.REVENUECAT_WEBHOOK_AUTH) {
      response.status(401).json({error: "unauthorized"});
      return;
    }

    const event = request.body && request.body.event;
    if (!event || typeof event !== "object") {
      response.status(400).json({error: "invalid_event"});
      return;
    }
    if (event.type === "TEST") {
      response.status(200).json({ok: true, test: true});
      return;
    }

    const uid = event.app_user_id;
    const eventId = event.id;
    const eventAtMs = Number(event.event_timestamp_ms || 0);
    if (
      typeof uid !== "string" ||
      uid.length < 1 ||
      uid.startsWith("$RCAnonymousID:") ||
      typeof eventId !== "string" ||
      !Number.isFinite(eventAtMs) ||
      eventAtMs <= 0
    ) {
      response.status(202).json({ok: true, ignored: "unsupported_identity"});
      return;
    }

    const entitlementIds = new Set(
      Array.isArray(event.entitlement_ids) ? event.entitlement_ids : [],
    );
    if (typeof event.entitlement_id === "string") {
      entitlementIds.add(event.entitlement_id);
    }
    const affectsPro = [...entitlementIds].some((id) => PRO_ENTITLEMENTS.has(id));
    const affectsCloud = [...entitlementIds].some((id) =>
      CLOUD_ENTITLEMENTS.has(id),
    );
    if (!affectsPro && !affectsCloud) {
      response.status(202).json({ok: true, ignored: "unrelated_entitlement"});
      return;
    }

    const isExpiration = event.type === "EXPIRATION";
    if (!isExpiration && !ACTIVE_EVENT_TYPES.has(event.type)) {
      // Cancellation and billing issues do not revoke access before expiration.
      response.status(202).json({ok: true, ignored: "non_terminal_event"});
      return;
    }

    const active = !isExpiration;
    const expirationAt = Number.isFinite(Number(event.expiration_at_ms))
      ? Timestamp.fromMillis(Number(event.expiration_at_ms))
      : null;
    const ref = getFirestore()
      .collection("users")
      .doc(uid)
      .collection("entitlements")
      .doc("current");

    await getFirestore().runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const current = snapshot.data() || {};
      const update = {
        serverRevenueCatUpdatedAt: FieldValue.serverTimestamp(),
        serverRevenueCatEnvironment: event.environment || null,
      };

      if (
        affectsPro &&
        eventAtMs >= Number(current.serverRevenueCatProEventAtMs || 0)
      ) {
        update.serverRevenueCatProActive = active;
        update.serverRevenueCatProProductId = event.product_id || null;
        update.serverRevenueCatProExpiresAt = expirationAt;
        update.serverRevenueCatProEventAtMs = eventAtMs;
        update.serverRevenueCatProEventId = eventId;
      }
      if (
        affectsCloud &&
        eventAtMs >= Number(current.serverRevenueCatCloudEventAtMs || 0)
      ) {
        update.serverRevenueCatCloudBackupActive = active;
        update.serverRevenueCatCloudProductId = event.product_id || null;
        update.serverRevenueCatCloudExpiresAt = expirationAt;
        update.serverRevenueCatCloudEventAtMs = eventAtMs;
        update.serverRevenueCatCloudEventId = eventId;
      }
      transaction.set(ref, update, {merge: true});
    });

    response.status(200).json({ok: true});
  },
);

exports.syncRevenueCatEntitlement = onRequest(
  {
    region: "asia-northeast3",
    secrets: ["REVENUECAT_SECRET_API_KEY"],
    maxInstances: 10,
    timeoutSeconds: 30,
  },
  async (request, response) => {
    if (request.method !== "POST") {
      response.set("Allow", "POST").status(405).json({error: "method_not_allowed"});
      return;
    }

    const authorization = request.get("authorization");
    if (!authorization || !authorization.startsWith("Bearer ")) {
      response.status(401).json({error: "missing_firebase_token"});
      return;
    }

    let decodedToken;
    try {
      decodedToken = await getAuth().verifyIdToken(authorization.slice(7));
    } catch (_) {
      response.status(401).json({error: "invalid_firebase_token"});
      return;
    }

    const uid = decodedToken.uid;
    const revenueCatResponse = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
      {
        headers: {
          Accept: "application/json",
          Authorization: `Bearer ${process.env.REVENUECAT_SECRET_API_KEY}`,
        },
      },
    );
    const payload = await revenueCatResponse.json();
    if (!revenueCatResponse.ok) {
      console.warn("RevenueCat subscriber lookup rejected", {
        status: revenueCatResponse.status,
        code: payload.code,
        message: payload.message,
      });
      response.status(502).json({error: "revenuecat_lookup_failed"});
      return;
    }

    const entitlements = payload.subscriber?.entitlements || {};
    const now = Date.now();
    const entitlementState = (ids) => {
      for (const id of ids) {
        const info = entitlements[id];
        if (!info) continue;
        const expirationMs = info.expires_date
          ? Date.parse(info.expires_date)
          : null;
        const active = expirationMs === null || expirationMs > now;
        if (active) {
          return {
            active: true,
            productId: info.product_identifier || null,
            expirationMs,
          };
        }
      }
      return {active: false, productId: null, expirationMs: null};
    };

    const pro = entitlementState(PRO_ENTITLEMENTS);
    const cloud = entitlementState(CLOUD_ENTITLEMENTS);
    const ref = getFirestore()
      .collection("users")
      .doc(uid)
      .collection("entitlements")
      .doc("current");
    const syncedAtMs = Date.now();
    await ref.set(
      {
        serverRevenueCatProActive: pro.active,
        serverRevenueCatProProductId: pro.productId,
        serverRevenueCatProExpiresAt: pro.expirationMs
          ? Timestamp.fromMillis(pro.expirationMs)
          : null,
        serverRevenueCatProEventAtMs: syncedAtMs,
        serverRevenueCatCloudBackupActive: cloud.active,
        serverRevenueCatCloudProductId: cloud.productId,
        serverRevenueCatCloudExpiresAt: cloud.expirationMs
          ? Timestamp.fromMillis(cloud.expirationMs)
          : null,
        serverRevenueCatCloudEventAtMs: syncedAtMs,
        serverRevenueCatUpdatedAt: FieldValue.serverTimestamp(),
        serverRevenueCatSyncSource: "rest_api",
      },
      {merge: true},
    );

    response.status(200).json({
      proActive: pro.active,
      cloudBackupActive: cloud.active,
    });
  },
);
