# Maizena Web Game

Juego 2D en Godot con export Web/PWA.

## Stack
- Godot 4.6
- GDScript
- Dialogue Manager (addon)

## Estructura principal
- `scenes/`: escenas del juego y objetos interactivos
- `scripts/`: logica de gameplay/UI
- `autoload/`: singletons globales (`GameState`, `DialogueController`, `HongosSpawner`)
- `dialogues/`: recursos `.dialogue`
- `web_build/`: salida de export Web

## Como ejecutar
1. Abrir el proyecto en Godot.
2. Ejecutar la escena principal configurada en `project.godot` (`res://scenes/main_scene.tscn`).

## Export Web
El preset Web se define en `export_presets.cfg` y la salida apunta a `web_build/index.html`.

Después de cada export desde Godot, ejecutar:

```bash
./tools/patch_web_build.sh
```

Eso ajusta el service worker para priorizar red sobre caché en `index.html`, `.pck` y `.wasm` (evita que los usuarios vean builds viejos). Netlify despliega automáticamente desde `web_build/`; los headers de caché están en `netlify.toml`.

## Smoke test recomendado (manual)
1. Iniciar partida y confirmar que el jugador se mueve con teclado/tap.
2. Hablar con `el_viejo` y aceptar la quest de comida.
3. Verificar que aparece un hongo en una posicion valida.
4. Recoger el hongo y confirmar cambio de estado de quest.
5. Volver con `el_viejo` y completar la quest sin errores.
6. Abrir/cerrar Settings y validar volumen + bloqueo de input.

## Integrantes
- Tobias Gencarelli
- Felipe Pagani
- Nicolas de la Cruz
