# Maizena Web Game

Juego 2D en Godot con export Web/PWA.

## Stack
- Godot 4.7
- GDScript
- Dialogue Manager (addon)

## Estructura principal
- `scenes/boot/`: boot (`loading_screen`, `main_scene`)
- `scenes/world/`: mapas Tiled (`bosque_encantado`, `ciudad_world`, `pantano_world`)
- `scenes/entities/`: NPCs, carteles, lugares y props (cada uno con su `.dialogue`)
- `scenes/ui/`: settings, noticias, banner, minimap, balloon, joystick
- `scripts/systems|ui|gameplay/`: logica de sistemas, UI y gameplay
- `autoload/`: singletons globales (`GameState`, `WorldState`, `MaizenaMeta`, `DialogueController`, `HongosSpawner`, `CordobaWeather`, `ViewportLayout`, `WorldMetrics`)
- `assets/art|audio|fonts/`: arte, musica y tipografia
- `web_build/`: salida de export Web (artefacto de deploy Netlify)
- `netlify/`: functions serverless (metricas)

## Como ejecutar
1. Abrir el proyecto en Godot.
2. Ejecutar con F5 o la escena principal configurada en `project.godot` (`res://scenes/boot/loading_screen.tscn`).

## Export Web
El preset Web se define en `export_presets.cfg` y la salida apunta a `web_build/index.html`.

Después de cada export desde Godot, ejecutar:

```bash
./tools/patch_web_build.sh
```

Eso ajusta el service worker para priorizar red sobre caché en `index.html`, `.pck` y `.wasm` (evita que los usuarios vean builds viejos). Netlify despliega automáticamente desde `web_build/` al commitear/pushear; los headers de caché están en `netlify.toml`.

## Smoke test recomendado (manual)
1. Iniciar partida y confirmar que el jugador se mueve con teclado/tap.
2. Hablar con `el_viejo` y aceptar la quest de comida.
3. Verificar que aparece un hongo en una posicion valida.
4. Recoger el hongo y confirmar cambio de estado de quest.
5. Volver con `el_viejo` y completar la quest sin errores.
6. Abrir/cerrar Settings y validar volumen + bloqueo de input.

## Equipo de desarrollo
- Tobias Gencarelli
- Nicolas de la Cruz
- Candela Gencarelli
