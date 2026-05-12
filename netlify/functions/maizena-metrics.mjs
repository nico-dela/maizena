/**
 * Ingesta JSON de Maizena (Godot Web). Variables de entorno en Netlify:
 * - METRICS_INGEST_SECRET (opcional): si está definida, el cliente debe enviar el mismo valor en la cabecera X-Maizena-Metrics-Secret.
 * - METRICS_FORWARD_URL (opcional): si está definida, reenvía el body a esa URL (Zapier, Slack, otro backend).
 *
 * CORS: permite POST desde cualquier origen (GitHub Pages u otro host del juego).
 */
export const handler = async (event) => {
  const headers = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type, X-Maizena-Metrics-Secret",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Content-Type": "application/json",
  };

  if (event.httpMethod === "OPTIONS") {
    return { statusCode: 204, headers, body: "" };
  }

  if (event.httpMethod !== "POST") {
    return { statusCode: 405, headers, body: JSON.stringify({ ok: false, error: "method" }) };
  }

  const want = process.env.METRICS_INGEST_SECRET || "";
  if (want) {
    const got = event.headers["x-maizena-metrics-secret"] || event.headers["X-Maizena-Metrics-Secret"] || "";
    if (got !== want) {
      return { statusCode: 401, headers, body: JSON.stringify({ ok: false, error: "secret" }) };
    }
  }

  const forward = process.env.METRICS_FORWARD_URL || "";
  if (forward) {
    try {
      await fetch(forward, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: event.body || "{}",
      });
    } catch (e) {
      console.error("[maizena-metrics] forward error", e);
    }
  }

  console.log("[maizena-metrics]", event.body);
  return { statusCode: 200, headers, body: JSON.stringify({ ok: true }) };
};
