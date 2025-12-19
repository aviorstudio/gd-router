# gd-router

Minimal, game-agnostic scene router for Godot 4 (route name → scene path).

- Package: `@aviorstudio/gd-router`
- Godot: `4.x` (tested on `4.4`)

## Install

Place this folder under `res://addons/<addon-dir>/` (for example `res://addons/@aviorstudio_gd-router/`).

- With `gdpm`: install/link into your project's `addons/`.
- Manually: copy or symlink this repo folder into `res://addons/<addon-dir>/`.

## Enable

Enable the plugin (`Project Settings -> Plugins -> GD Router`) to install an autoload named `GdRouter`.

Alternatively, add `autoload.gd` as an autoload named `GdRouter`.

## Files

- `plugin.cfg` / `plugin.gd`: editor plugin that installs the `GdRouter` autoload.
- `autoload.gd`: autoload entrypoint (extends `src/router_service.gd`).
- `src/router_service.gd`: router implementation.

## Usage

```gdscript
GdRouter.go_to("home")
```

Configure routes explicitly:

```gdscript
GdRouter.set_routes({
	"home": "res://src/routes/home_route/home_route.tscn",
	"login": "res://src/routes/login_route/login_route.tscn",
})
```

## Configuration

When `gd_router/auto_discover` is enabled, routes are discovered from directories under `gd_router/routes_dir` that end in `gd_router/route_dir_suffix`.

Each route directory must contain a scene named `<dir>/<dir>.tscn` (for example `res://src/routes/home_route/home_route.tscn`).

Project settings:

- `gd_router/auto_discover` (bool, default `true`)
- `gd_router/routes_dir` (string, default `res://src/routes`)
- `gd_router/route_dir_suffix` (string, default `_route`)

## Notes

- Auto-discovery is meant to be overridden per-project; disable it and call `set_routes(...)` if your routing layout differs.
