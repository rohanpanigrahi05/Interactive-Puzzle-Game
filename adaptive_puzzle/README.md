# ADAPTIVE PUZZLE ⚡

A high-performance, cyberpunk-themed logic puzzle arcade built with Flutter. Features persistent offline storage, web audio synthesis, custom-painted glowing neon visuals, particle effects, and algorithmic challenge modes.

---

## 🎮 Game Modes

* **Synapse Flow**: Rotate procedurally generated circuit nodes on an $N \times N$ grid using bitwise connection logic to propagate power from the source to the target terminal. Includes an Auto-Align power-up.
* **Digital Escape Room**: Progress through 5 escalating security chambers (Cryo Labs, Reactor Core, Cybernetics Bay, Bio-Containment, AI Core Nexus). Balance dial sums, toggle polarity matrices, decode terminal logs, and unlock the master escape airlock under a countdown timer.
* **Block Escape**: A multi-directional sliding block puzzle. Maneuver blocking conduits up, down, left, and right on a $6 \times 6$ grid to clear an exit trajectory for the Prime Core.

---

## ✨ Features

* **Global Wallet & Progression**: Earn arcade points across all modes to purchase and equip cosmetic node skins via the Cyberpunk Store.
* **Web & Desktop Audio Synthesizer**: Custom JavaScript Web Audio API oscillator fallback alongside native Flutter haptic feedback.
* **Responsive Scaffolding**: Automatically transitions between a focused vertical layout on mobile and a telemetry dashboard split-view on desktop/web.
* **Self-Verifying Engine**: Automated unit tests run on app boot (`ArcadeEngineVerifier`) to validate bitmask rotations, DFS/BFS graph power propagation, and spatial boundary constraints.

---

## 🛠️ Tech Stack

* **Framework**: [Flutter](https://flutter.dev/) (Web, Mobile, Desktop)
* **Language**: [Dart](https://dart.dev/)
* **Interoperability**: `dart:js_interop` for local storage persistence and Web Audio API synthesis
* **Graphics**: Custom Flutter `CustomPainter` pipelines with canvas blur and particle animations

---

## 🚀 Getting Started

### Prerequisites

* Flutter SDK (3.19.0 or higher recommended)
* Dart SDK
