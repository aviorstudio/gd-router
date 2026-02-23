# gd-router

Scene routing service for Godot 4 with optional auto-discovery and transitions.

## Installation

### Via gdpm
`gdpm install @aviorstudio/gd-router`

### Manual
Copy this directory into `addons/@aviorstudio_gd-router/` and enable the plugin.

## Quick Start

```gdscript
GdRouter.set_routes({
	"home": "res://src/routes/home_route/home_route.tscn",
})
GdRouter.go_to("home")
```

## API Reference

- `RouterService`: route registration, navigation, history, and params.
- `RouteTransitionUtil`: reusable crossfade scene transition callable.
- `autoload.gd`: `GdRouter` autoload entrypoint.

## Configuration

- `gd_router/auto_discover`
- `gd_router/routes_dir`
- `gd_router/route_dir_suffix`

## Testing

`./tests/test.sh`

## License

MIT
