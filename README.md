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

## Equipo de desarrollo
- Tobias Gencarelli
- Candela Gencarelli
- Nicolas de la Cruz
