# Gully Dash: India Rush

**Gully Dash** is an offline-first, portrait-mode 2D arcade endless runner starring an Indian auto-rickshaw. It is built in Godot 4 with GDScript; the early project uses procedural placeholder art to keep iteration quick and free of asset licensing surprises.

## Current implementation

- Three-lane road with smooth, bounded lane switching.
- Tap and horizontal-swipe controls, plus keyboard controls for desktop testing.
- Procedural auto-rickshaw/player and traffic illustrations.
- Traffic spawner, collision/game-over, restart, progressive speed and distance/score tracking.
- Chai coins, passenger-rush score multiplier, shield and 2x reward pickups.
- Local persistence for best score, wallet, lifetime stats, mission rewards and unlocked/selected skins.
- Main menu, garage, challenges, settings, pause/resume, and Android back/exit flow.
- Sound/haptic/reduced-motion preferences. Arcade tones are generated at runtime; they are placeholders for later original sound design.
- No login, networking, ads or backend in the initial milestones.

## Toolchain

- Godot **4.7.2 stable** (pinned in CI and Docker).
- GDScript; Compatibility renderer for broad Android device support.
- OpenJDK 17 and Android SDK Platform 36 in the Docker build image.
- Dockerized headless import, smoke tests and Android debug APK export.

## Run in Godot

1. Install [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/).
2. Clone this repository and open `project.godot` using Godot's **Import** dialog.
3. Press **F5** to launch the main scene.

Controls: Left/Right or A/D to steer; swipe horizontally or tap the left/right side on a touchscreen. Press P or Escape to pause on desktop. The pause/menu screen explains the touch controls.

## Build a debug APK with Docker

Requires Docker Engine/Desktop. The first build downloads pinned Godot/export templates and Android SDK components, so it is a large image and needs network access.

```bash
git clone https://github.com/omnayak27199/gully-dash.git
cd gully-dash

docker build -t gully-dash-android-builder .

docker run --rm \
  --user "$(id -u):$(id -g)" \
  --env HOME=/tmp/godot-home \
  --volume "$PWD:/workspace" \
  --workdir /workspace \
  gully-dash-android-builder debug-apk
```

If successful, the installable **debug-only** APK is at `build/GullyDash-debug.apk`. Transfer it to an Android phone and install it for a real touchscreen/performance test (you may need to allow installation from that source). This APK is for testing, **not** for Play Store submission.

GitHub Actions includes:
- **Godot validation** — headless project import plus player, game-flow and save-recovery tests.
- **Android debug build** — containerized APK export and an artifact named `gully-dash-debug-apk`. Open the repository's Actions tab and download the artifact from a successful run.

## Save data

The game saves progress locally using a versioned ConfigFile with a temporary-write/rename sequence and a previous known-good backup. Uninstalling the game can remove this local progress; no cloud sync is included.

## Roadmap and release boundary

See [docs/ROADMAP.md](docs/ROADMAP.md). Milestones 1–5 have implementation in this branch, but editor/CI/device verification must pass before calling the build release-ready. Ads, release signing, privacy-policy hosting, Play Console forms and store submission are deliberately in Milestones 6–7.

## Licensing

No project license has been selected yet. Until a license is added, normal copyright applies. Keep the source/assets you add original or correctly licensed and record third-party asset licenses before release.
