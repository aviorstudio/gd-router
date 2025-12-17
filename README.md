# gd-router

Minimal, game-agnostic scene router addon for Godot.

## Files
- `src/router_service.gd`: router implementation
- `autoload.gd`: autoload entrypoint (extends `src/router_service.gd`)
- `plugin.gd` / `plugin.cfg`: editor plugin that installs the `RouterService` autoload

## Usage
- Enable the plugin, then use `GdRouter.go_to(...)`.
- By default it auto-discovers routes under `res://src/routes` (directories ending in `_route` map to route names without the suffix).
- Override behavior via `ProjectSettings`:
  - `gd_router/auto_discover` (bool, default `true`)
  - `gd_router/routes_dir` (string, default `res://src/routes`)
  - `gd_router/route_dir_suffix` (string, default `_route`)
- Or configure explicitly via `GdRouter.set_routes(...)` / `GdRouter.add_route(...)`.
- Or extend `res://addons/<your-addon>/src/router_service.gd` in your own navigation autoload and call `set_routes(...)` there.
