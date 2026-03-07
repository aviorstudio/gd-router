# gd-router

Minimal scene navigation primitive for Godot 4 with optional transition effects.

This addon intentionally avoids route-driven app orchestration. Keep scene setup and feature lifecycle in game code.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-router`

### Manual
Copy this directory into `addons/@aviorstudio_gd-router/` and enable the plugin.

## Quick Start

```gdscript
const RouterService = preload("res://addons/@aviorstudio_gd-router/src/router_service.gd")

GdRouter.set_routes({
	"home": RouterService.RouteEntry.new("home", "res://src/routes/home_route/home_route.tscn"),
})
GdRouter.go_to("home")
```

## API Reference

- `RouterService`: route registration, navigation, history, and params.
- `RouteMiddlewareAdapter`: middleware object contract (`run(route_name, params, next)`).
- `RouteTransitionUtil`: replaceable crossfade effect helper.
- `autoload.gd`: `GdRouter` autoload entrypoint.

## Scope Boundary

- In scope: route table registration and scene navigation calls.
- Out of scope: feature/module bootstrapping, state orchestration, and route-specific business logic.

## Configuration

- `gd_router/auto_discover`
- `gd_router/routes_dir`
- `gd_router/route_dir_suffix`

`gd_router/auto_discover` defaults to `false`. Explicit route registration is recommended.

## Testing

`./tests/test.sh`

## License

MIT
