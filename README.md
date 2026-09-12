# Maizena Web Game

Juego 2D en Godot con export Web/PWA.

## Stack
- Godot 4.7
- GDScript
- Dialogue Manager (addon)

## Estructura principal
- `scenes/`: escenas del juego y objetos interactivos
- `scripts/`: logica de gameplay/UI
- `autoload/`: singletons globales (`GameState`, `WorldState`, `MaizenaMeta`, `DialogueController`, `HongosSpawner`, `CordobaWeather`, `ViewportLayout`, `WorldMetrics`)
- `dialogues/`: recursos `.dialogue`
- `web_build/`: salida de export Web (artefacto de deploy Netlify)
- `netlify/`: functions serverless (metricas)

## Como ejecutar
1. Abrir el proyecto en Godot.
2. Ejecutar con F5 o la escena principal configurada en `project.godot` (`res://scenes/loading_screen.tscn`).

## Equipo de desarrollo
- Tobias Gencarelli
- Candela Gencarelli
- Nicolas de la Cruz
