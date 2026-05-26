# gd-router

Navigate between scenes by route name in Godot 4.

Use this addon when you want a small `GdRouter` autoload for route registration, navigation history, params, middleware, and optional transitions.

## Installation

### Via gdam

`gdam install @aviorstudio/gd-router`

### Manual

Copy `addon/` into `res://addons/@aviorstudio_gd-router/` and enable the plugin.

## Quick Start

The plugin installs an autoload named `GdRouter`.

```gdscript
const RouterService = preload("res://addons/@aviorstudio_gd-router/src/router_service.gd")

func _ready() -> void:
	GdRouter.set_routes({
		"home": RouterService.RouteEntry.new("home", "res://src/routes/home_route/home_route.tscn"),
		"settings": RouterService.RouteEntry.new("settings", "res://src/routes/settings_route/settings_route.tscn"),
	})

	GdRouter.go_to("home")
```

## Navigation

```gdscript
GdRouter.go_to("settings", {"tab": "audio"})
GdRouter.replace("home")
GdRouter.go_back()
```

## What You Get

- `RouterService`: route table, current route, params, and history.
- `GdRouter`: default autoload entrypoint.
- `RouteEntry`: route name and scene path container.
- `RouteMiddlewareAdapter`: middleware contract with `run(route_name, params, next)`.
- `RouteTransitionUtil`: replaceable crossfade helper.

## Auto Discovery

The router can auto-discover scenes that follow this convention:

```text
res://src/routes/*_route/*_route.tscn
```

Project settings:

- `gd_router/auto_discover`
- `gd_router/routes_dir`
- `gd_router/route_dir_suffix`

Explicit route registration is recommended for larger projects or custom folder layouts.

## Notes

- Works in Godot 4.x native and web exports.
- Game-specific guards, loading screens, and feature lifecycle should live in your game code.

## Testing

`./tests/test.sh`

## License

MIT
