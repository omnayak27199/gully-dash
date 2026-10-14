# Gully Dash: India Rush — Roadmap

## Product goal

Build a small, polished, portrait-mode Android arcade game that can be played offline. Keep the early version asset-light and avoid a backend until a real feature requires one.

## Milestone 1 — Playable prototype

- [x] Godot 4 project and main scene
- [x] Three-lane road and player lane movement
- [x] Traffic obstacles and collision/game-over
- [x] Distance score, coin collection, restart
- [ ] Run and validate in the Godot editor
- [ ] Test controls on a real Android phone

## Milestone 2 — Make the core loop fun

- Tune obstacle frequency and speed curve
- Add better lane-transition and collision feedback
- Add simple sound and vibration toggles
- Test short and long play sessions
- Keep a clear, readable UI on small screens

## Milestone 3 — Indian visual identity

- Replace placeholder drawings with original or correctly licensed art
- Add road-side details and a few traffic variants
- Add auto-rickshaw skins and unlock conditions
- Add a menu and settings screen
- Document sources and licenses for every shipped asset

## Milestone 4 — Progression and retention

- Persistent best score and coins
- Daily challenge only if it can be implemented without unnecessary backend complexity
- Balance rewards so the game remains fun without ads
- Test save-file behavior across updates

## Milestone 5 — Android packaging

- Install and pin a compatible Godot 4 release and export templates
- Configure Android SDK and JDK using the official Godot documentation
- Generate a debug APK and test on-device
- Configure release signing; store keystore and passwords outside Git
- Add a pinned Docker build image/script after manual export is verified

## Milestone 6 — Monetization and store release

- Integrate AdMob only after gameplay is stable
- Use test ad units during development
- Add privacy policy and accurately complete Play Console Data safety/ads declarations
- Test through Play internal/closed testing tracks
- Review performance, crashes, retention and feedback before spending on promotion

## Initial non-goals

- No login, multiplayer, online leaderboard or custom backend in the first version
- No paid user acquisition before testing organic interest
- No copied movie, game, brand, or copyrighted music assets
