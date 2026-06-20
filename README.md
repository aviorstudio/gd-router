# gd-router

Editor-first hosted screen routing for Godot 4 app shells.

Use this addon when your project has a persistent main scene and wants to route between screen scenes inside a `RouteHost`. `GdRouter` owns navigation state, params, and history; `RouteHost` owns the mounted screen node.

## Installation

### Via gdam

`gdam install @aviorstudio/gd-router`

### Manual

Copy `addon/` into `res://addons/@aviorstudio_gd-router/` and enable the plugin.

## Quick Start

The plugin installs an autoload named `GdRouter` and adds editor types for `RouteHost`, `RouteMap`, `RouteDefinition`, `RouteTransition`, and `RouteLink`.

Create a main scene like this:

```text
Main.tscn
  RouteHost
```

Create screens like this:

```text
res://src/screens/home_screen/home_screen.tscn
res://src/screens/game_screen/game_screen.tscn
```

Select `RouteHost` in the editor and set:

- `initial_route`: `home`
- `auto_discover`: `true`
- `routes_dir`: `res://src/screens`
- `route_dir_suffix`: `_screen`

Navigate from code:

```gdscript
func _on_play_button_pressed() -> void:
	GdRouter.go_to("game", {"level": "level_01"})
```

Or add a `RouteLink` button and set its `route_name` in the Inspector.

## Recommended Project Shape

```text
res://src/main/main.tscn
res://src/screens/home_screen/home_screen.tscn
res://src/screens/game_screen/game_screen.tscn
res://src/static/config/main_route_map.tres
```

`main.tscn` should stay persistent for app startup, autoload coordination, telemetry, audio, save systems, and other shell-level lifecycle. Routed screens should be mounted under a `RouteHost` child.

## Navigation

```gdscript
GdRouter.go_to("settings", {"tab": "audio"})
GdRouter.replace("home")
GdRouter.go_back()
```

## What You Get

- `GdRouter`: autoload navigation API, route table, params, and history.
- `RouteHost`: scene-tree outlet that mounts the active screen as a child.
- `RouteMap`: editor-visible route list resource for production projects.
- `RouteDefinition`: route name, screen scene path, metadata, and optional guard.
- `RouteTransition`: assignable transition resource.
- `InstantRouteTransition`: no-animation transition.
- `CrossfadeRouteTransition`: simple screen crossfade and slide transition.
- `RouteLink`: button node that navigates to a route from Inspector data.

## Auto Discovery

The router can auto-discover scenes that follow this convention:

```text
res://src/screens/*_screen/*_screen.tscn
```

For example, `res://src/screens/home_screen/home_screen.tscn` becomes route `home`.

Auto-discovery is useful while prototyping. A committed `RouteMap.tres` is recommended for larger projects because routes become inspectable and reviewable in the Godot editor.

## Route Maps

Create a `RouteMap` resource and assign it to `RouteHost.route_map` when you want explicit editor-authored routes. Each `RouteDefinition` can set:

- `route_name`
- `scene_path`
- `title`
- `metadata`
- `guard`

When a `RouteMap` is assigned, `RouteHost` uses it instead of auto-discovery.

For production projects, prefer a committed route map over auto-discovery. Auto-discovery is excellent for early prototyping, but a `RouteMap.tres` gives designers and reviewers an explicit source of truth in the editor.

If `RouteHost.initial_route` is empty, the host uses `RouteMap.initial_route`.

## Transitions

Assign a `RouteTransition` resource to `RouteHost.transition`.

Built-in transitions:

- `InstantRouteTransition`: swaps screens without animation.
- `CrossfadeRouteTransition`: fades between screens with a small slide-in.

Custom transitions should extend `RouteTransition` and emit `finished` when the host may free the previous screen.

## Guards

Assign a `RouteGuard` resource to `RouteDefinition.guard` when a route needs to block entry.

```gdscript
extends RouteGuard

func can_enter(context: RouteContext) -> bool:
	return context.params.get("unlocked", false)
```

Guards run before the host loads the target scene. A blocked guard leaves the current route and history unchanged.

## App Shell Model

`gd-router` is designed around a persistent app shell:

```text
Main scene: app startup, autoload coordination, observability, layout shell
RouteHost: mounted active screen
Screens: authored destination scenes
Components: reusable parts inside screens
```

The router does not replace the whole `SceneTree.current_scene` by default. Whole-scene replacement is intentionally not the primary model because it makes global app lifecycle and editor-authored shells harder to manage.

## Example

This repository includes a small app-shell example:

```text
examples/app_shell/main.tscn
examples/app_shell/src/static/config/main_route_map.tres
examples/app_shell/src/screens/home_screen/home_screen.tscn
examples/app_shell/src/screens/game_screen/game_screen.tscn
```

It demonstrates `RouteHost`, `RouteMap`, and `RouteLink` together.

## Local Addon Development

Use GDAM links to test unreleased addon changes in a game project:

```sh
gdam link @aviorstudio/gd-router /path/to/gd-router/addon
gdam install
```

Keep `gdam.link.json` local. If it lives under `res://`, exclude it from exports so local paths are never packed into builds.

## Notes

- Works in Godot 4.x native and web exports.
- Game-specific guards, loading screens, and feature lifecycle should live in your game code.

## Repository Layout

- `addon/`: Godot plugin source packaged for GDAM and manual installation.
- `addon/plugin.cfg`: plugin name, version, description, and entry script.
- `addon/src/core/`: navigation state and request objects.
- `addon/src/nodes/`: editor-visible routing nodes.
- `addon/src/resources/`: editor-visible route, guard, and transition resources.
- `addon/src/discovery/`: screen route discovery.
- `tests/`: Godot test project/scripts for addon behavior.
- `.github/workflows/ci.yml`: validates package shape and runs tests.
- `.github/workflows/release.yml`: creates GitHub release ZIPs and publishes to GDAM.

## Versioning And Releases

The version in `addon/plugin.cfg` is the addon package version. Releases are created from `main` with the manual release workflow and plain semver tags like `v0.0.1`; the workflow verifies `plugin.cfg`, builds `@aviorstudio_gd-router.zip`, and publishes `@aviorstudio/gd-router` to GDAM.

## Testing

Run locally with:

```sh
./tests/test.sh
```

CI runs the same test script when available.

## License

MIT
