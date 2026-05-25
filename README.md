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

Navigation helpers:

- `go_to(route_name, params)`: navigate and append to history.
- `replace(route_name, params)`: navigate without adding a new history entry.
- `go_back()`: navigate to the previous route when history is available.

## Scope Boundary

- In scope: route table registration and scene navigation calls.
- Out of scope: feature/module bootstrapping, state orchestration, and route-specific business logic.

## Configuration

- `gd_router/auto_discover`
- `gd_router/routes_dir`
- `gd_router/route_dir_suffix`

`gd_router/auto_discover` defaults to `true` for small projects that follow the `res://src/routes/*_route/*_route.tscn` convention. Explicit route registration is recommended for larger projects or projects with a different folder layout.

## Compatibility

- Godot 4.x.
- Native and web exports.
- The default autoload is `GdRouter`.

## API Stability

The stable public API is `RouterService`, `GdRouter`, route entries, middleware objects with `run(route_name, params, next)`, and route params/history helpers. Game-specific guards and feature lifecycle should stay in game code.

## Testing

`./tests/test.sh`

## License

MIT
