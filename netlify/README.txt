Métricas Maizena + Netlify / GitHub Pages
======================================

1) Godot — Project Settings → crear o editar claves (también en project.godot sección [maizena]):

   maizena/metrics/endpoint
	 URL HTTPS del endpoint. Ejemplo si el juego y Netlify comparten sitio:
	 https://TU-SITIO.netlify.app/.netlify/functions/maizena-metrics

   maizena/metrics/ingest_secret (opcional)
	 Misma cadena que METRICS_INGEST_SECRET en Netlify (no subas secretos al repo público:
	 configura el valor solo en el panel de Netlify y en export presets locales si hace falta).

2) Netlify — Environment variables:

   METRICS_INGEST_SECRET   (opcional) protege el POST.
   METRICS_FORWARD_URL     (opcional) webhook Zapier / Supabase / etc.

3) GitHub Pages

   Si el HTML del juego está en otro dominio que Netlify, el POST es cross-origin: la función ya
   responde con Access-Control-Allow-Origin: * y OPTIONS para preflight.

4) Payload (JSON)

   phase: "start" | "tick" | "end"
   client_id: estable por navegador (user:// en web = IndexedDB/local del export).
   session_id: nuevo cada carga del juego.
   wall_sec, active_play_sec, songs_by_title, song_starts_total, dialogues_by_resource,
   dialogue_opens_total, era, world_day, accumulation_level, os_name, locale, welcome_seen.

5) Persistencia de métricas

   La función por defecto solo hace console.log. Para guardar datos usa METRICS_FORWARD_URL
   hacia tu base (Supabase REST, Airtable, etc.) o amplía la función (Redis, etc.).
