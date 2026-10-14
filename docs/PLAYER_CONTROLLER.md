# Player Controller Module

The player is implemented as a reusable scene at `scenes/player_auto.tscn`, with its behavior in `scripts/player_controller.gd`.

## Responsibilities

- Owns the selected lane and smooth horizontal movement.
- Emits `lane_changed(previous_lane, current_lane)` only when the selected lane changes.
- Rejects invalid directions, disabled input, and movement beyond lane boundaries.
- Owns the player's visual placeholder drawing and forgiving collision rectangle.
- Provides `reset_player()` to return to center lane, restore visibility, and clear steering rotation.

## Public API

| API | Purpose |
| --- | --- |
| `change_lane(direction: int) -> bool` | Request one adjacent lane; returns whether the target changed. |
| `set_controls_enabled(enabled: bool)` | Enable/disable steering requests. |
| `reset_player()` | Reset position, lane, rotation, visibility and input state. |
| `get_hitbox_rect() -> Rect2` | Collision bounds in the parent viewport's coordinate space. |

## Coordinate assumptions

The current prototype uses a fixed logical viewport of 540×960 with lane centers at x=135, 270, and 405. Player movement uses a fixed vertical position of y=790, assigned by the game coordinator. These values belong to the current prototype and should move into a shared configuration/resource when the world module is extracted.

## Tests

Run `godot --headless --editor --path . --quit` once to import the project, then `godot --headless --path . --script res://tests/player_controller_test.gd`.

The GitHub Actions workflow runs the same smoke test using a pinned Godot stable release. A successful workflow is required before merging this branch.
