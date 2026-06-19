#!/usr/bin/env bash
# Ejecutar después de exportar Web desde Godot:
#   godot4 --headless --export-release "Web" && ./tools/patch_web_build.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SW="$ROOT/web_build/index.service.worker.js"

if [[ ! -f "$SW" ]]; then
  echo "No se encontró $SW — exportá Web primero." >&2
  exit 1
fi

python3 <<'PY'
from pathlib import Path

sw_path = Path("web_build/index.service.worker.js")
text = sw_path.read_text(encoding="utf-8")

old = """\t\tif (isNavigate || isCacheable) {
\t\t\tevent.respondWith((async () => {
\t\t\t\t// Try to use cache first
\t\t\t\tconst cache = await caches.open(CACHE_NAME);
\t\t\t\tif (isNavigate) {
\t\t\t\t\t// Check if we have full cache during HTML page request.
\t\t\t\t\t/** @type {Response[]} */
\t\t\t\t\tconst fullCache = await Promise.all(FULL_CACHE.map((name) => cache.match(name)));
\t\t\t\t\tconst missing = fullCache.some((v) => v === undefined);
\t\t\t\t\tif (missing) {
\t\t\t\t\t\ttry {
\t\t\t\t\t\t\t// Try network if some cached file is missing (so we can display offline page in case).
\t\t\t\t\t\t\tconst response = await fetchAndCache(event, cache, isCacheable);
\t\t\t\t\t\t\treturn response;
\t\t\t\t\t\t} catch (e) {
\t\t\t\t\t\t\t// And return the hopefully always cached offline page in case of network failure.
\t\t\t\t\t\t\tconsole.error('Network error: ', e); // eslint-disable-line no-console
\t\t\t\t\t\t\treturn caches.match(OFFLINE_URL);
\t\t\t\t\t\t}
\t\t\t\t\t}
\t\t\t\t}
\t\t\t\tlet cached = await cache.match(event.request);
\t\t\t\tif (cached != null) {
\t\t\t\t\tif (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
\t\t\t\t\t\tcached = ensureCrossOriginIsolationHeaders(cached);
\t\t\t\t\t}
\t\t\t\t\treturn cached;
\t\t\t\t}
\t\t\t\t// Try network if don't have it in cache.
\t\t\t\tconst response = await fetchAndCache(event, cache, isCacheable);
\t\t\t\treturn response;
\t\t\t})());
\t\t}"""

new = """\t\tif (isNavigate || isCacheable) {
\t\t\tevent.respondWith((async () => {
\t\t\t\tconst cache = await caches.open(CACHE_NAME);
\t\t\t\tconst preferNetwork = isNavigate || local === 'index.pck' || local === 'index.wasm' || local === 'index.js' || local === 'index.service.worker.js';
\t\t\t\tif (preferNetwork) {
\t\t\t\t\ttry {
\t\t\t\t\t\treturn await fetchAndCache(event, cache, isCacheable);
\t\t\t\t\t} catch (e) {
\t\t\t\t\t\tconsole.error('Network error: ', e); // eslint-disable-line no-console
\t\t\t\t\t\tif (isNavigate) {
\t\t\t\t\t\t\tlet cached = await cache.match(event.request);
\t\t\t\t\t\t\tif (cached != null) {
\t\t\t\t\t\t\t\tif (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
\t\t\t\t\t\t\t\t\tcached = ensureCrossOriginIsolationHeaders(cached);
\t\t\t\t\t\t\t\t}
\t\t\t\t\t\t\t\treturn cached;
\t\t\t\t\t\t\t}
\t\t\t\t\t\t\treturn caches.match(OFFLINE_URL);
\t\t\t\t\t\t}
\t\t\t\t\t}
\t\t\t\t}
\t\t\t\tlet cached = await cache.match(event.request);
\t\t\t\tif (cached != null) {
\t\t\t\t\tif (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
\t\t\t\t\t\tcached = ensureCrossOriginIsolationHeaders(cached);
\t\t\t\t\t}
\t\t\t\t\treturn cached;
\t\t\t\t}
\t\t\t\treturn await fetchAndCache(event, cache, isCacheable);
\t\t\t})());
\t\t}"""

if old not in text:
    if "preferNetwork" in text:
        print("OK service worker already patched", sw_path)
    else:
        raise SystemExit("service worker: bloque esperado no encontrado (¿Godot cambió la plantilla?)")
else:
    sw_path.write_text(text.replace(old, new, 1), encoding="utf-8")
    print("OK patched", sw_path)
PY

MAP_SRC="$ROOT/assets/ui/world_map_preview.png"
MAP_DST="$ROOT/web_build/world_map_preview.png"
if [[ -f "$MAP_SRC" ]]; then
  cp "$MAP_SRC" "$MAP_DST"
  echo "OK copied world_map_preview.png"
fi

python3 <<'PY'
from pathlib import Path
tpl = Path("full-size.html").read_text(encoding="utf-8")
pck = Path("web_build/index.pck")
wasm = Path("web_build/index.wasm")
pck_size = pck.stat().st_size if pck.exists() else 0
wasm_size = wasm.stat().st_size if wasm.exists() else 0
config = (
    '{"args":[],"canvasResizePolicy":2,"emscriptenPoolSize":8,'
    '"ensureCrossOriginIsolationHeaders":true,"executable":"index",'
    '"experimentalVK":false,"fileSizes":{"index.pck":%d,"index.wasm":%d},'
    '"focusCanvas":true,"gdextensionLibs":[],"godotPoolSize":4,'
    '"serviceWorker":"index.service.worker.js"}'
) % (pck_size, wasm_size)
out = tpl.replace("$GODOT_PROJECT_NAME", "Archipiélago Maizena")
out = out.replace("$GODOT_SPLASH", "index.png")
out = out.replace("$GODOT_URL", "index.js")
out = out.replace("$GODOT_CONFIG", config)
out = out.replace("$GODOT_THREADS_ENABLED", "true")
out = out.replace(
    "$GODOT_HEAD_INCLUDE",
    '<link id="-gd-engine-icon" rel="icon" type="image/png" href="index.icon.png" />\n'
    '<link rel="apple-touch-icon" href="index.apple-touch-icon.png"/>\n'
    '<link rel="manifest" href="index.manifest.json">',
)
Path("web_build/index.html").write_text(out, encoding="utf-8")
print("OK generated web_build/index.html")
PY

echo "Listo. Subí web_build/ a Netlify."
