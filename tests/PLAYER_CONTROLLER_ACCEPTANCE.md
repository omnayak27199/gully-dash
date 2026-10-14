# Player Controller — Acceptance Checklist

The controller module should pass the following checks in the Godot editor or in an Android debug build.

## Lane selection

- [ ] Player starts centered in lane 2 at viewport position (270, 790).
- [ ] One left request moves the target to lane 1; one right request moves it to lane 3.
- [ ] Requests beyond the left and right lane edges are ignored.
- [ ] Invalid direction values and requests while controls are disabled are ignored.
- [ ] A lane-change signal is emitted only when the current lane actually changes.

## Movement and reset

- [ ] Player eases toward the selected lane; the target lane updates immediately.
- [ ] An opposite lane request during movement retargets smoothly without a teleport.
- [ ] Steering tilt settles to zero after the move completes.
- [ ] Restart places the player in the center lane and clears its steering angle.
- [ ] The collision rectangle is narrower than the rendered player to feel fair.

## Input integration

- [ ] Keyboard Left/A and Right/D work in desktop testing.
- [ ] A short screen tap changes one lane according to the half tapped.
- [ ] A horizontal swipe changes one lane; a vertical swipe does not accidentally steer.
- [ ] Taps outside the restart button do not restart a finished run.
- [ ] The player is hidden and input is disabled after a collision.

## Validation status

This checklist is a test plan, not a claim that Godot runtime or device tests have already passed. Record actual results after opening the project in Godot 4 and testing on-device.
