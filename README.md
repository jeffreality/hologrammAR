# hologrammAR

A small Apple Vision Pro / RealityKit proof of concept that turns your open left hand into a hologram projector.

Open your palm and a randomly selected USDZ model appears above it as a glowing blue-white hologram. The model slowly rotates while illuminated rings orbit around it. Close your hand and the hologram disappears.

The project is intentionally small and experimental: the goal is to explore whether hand tracking, RealityKit anchoring, and lightweight visual effects can create a convincing "Princess Leia / R2-D2 hologram" interaction on Apple Vision Pro.

## Demo

https://github.com/user-attachments/assets/e73c5247-f2ed-487c-ad8c-af27166917ef

## What it does

* Tracks the user's **left hand** with ARKit.
* Detects an **open palm** and **closed hand**.
* Anchors virtual content above the hand using RealityKit.
* Randomly selects from bundled `.usdz` models.
* Normalizes arbitrary USDZ model sizes before displaying them.
* Slowly rotates the hologram.
* Adds blue-white emissive/translucent rendering.
* Adds wireframe detail to help preserve model definition.
* Adds rotating luminous rings and lightweight scan-style effects.
* Hides the hologram when the user closes their hand.
* Uses temporal stabilization so noisy hand-tracking samples don't cause the effect to flicker on and off.

## Interaction

```text
Open left palm
      ↓
Hologram appears
      ↓
USDZ slowly rotates
      ↓
Close hand
      ↓
Hologram disappears
```

Opening the hand again selects another model when multiple USDZ assets are available.

## Requirements

* Apple Vision Pro
* visionOS
* Xcode with the visionOS SDK
* A physical device for meaningful hand-tracking testing

Detailed skeletal hand tracking is the core of the interaction, so the simulator is useful for general development but not for validating the actual experience.

## Project structure

```text
hologrammAR/
├── App/
│   ├── AppModel.swift
│   └── HologrammARApp.swift
├── Extensions/
│   ├── Entity+Hologram.swift
│   ├── HandSkeleton+Position.swift
│   └── SIMD3+Distance.swift
├── Models/
│   ├── HandPose.swift
│   └── HologramAsset.swift
├── Services/
│   ├── HandPoseClassifier.swift
│   ├── HandTrackingService.swift
│   ├── HologramAssetLibrary.swift
│   ├── HologramMaterialFactory.swift
│   └── HologramSceneController.swift
├── Utilities/
│   └── TorusMeshFactory.swift
├── Views/
│   ├── ContentView.swift
│   ├── ImmersiveView.swift
│   └── Subviews/
│       └── StatusBadge.swift
└── Resources/
    └── Holograms/
        └── *.usdz
```

## Setup

### 1. Create or open the visionOS project

The project uses SwiftUI, RealityKit, and ARKit.

### 2. Add hand-tracking permission

Add the following privacy key to the app:

```text
Privacy - Hands Tracking Usage Description
```

Raw key:

```text
NSHandsTrackingUsageDescription
```

Example value:

```text
hologrammAR uses hand tracking to show and hide holograms above your hand.
```

### 3. Add USDZ models

Add one or more `.usdz` files to:

```text
Resources/Holograms/
```

Make sure the files are included in the app target.

The asset loader discovers the models at runtime, preloads them, and randomly selects one whenever a new hologram is summoned.

If no USDZ files are available, the project can fall back to a simple procedural model for testing.

## How it works

### Hand tracking

`HandTrackingService` runs an `ARKitSession` with `HandTrackingProvider` and listens for updates from the left hand.

`HandPoseClassifier` uses the relative positions of the finger joints to classify the hand as:

* open
* closed
* intermediate
* unknown

The classifier intentionally does not depend on every fingertip being perfectly tracked. Fingers naturally occlude one another when making a fist, so the interaction uses tolerant thresholds and temporal stabilization rather than expecting a perfect skeleton every frame.

### Hologram anchoring

The hologram is attached to a RealityKit hand anchor and positioned so that it appears over the center of the user's palm.

The presentation offset can be tuned in `HologramSceneController` to account for the visual relationship between the hand anchor and the perceived center of the palm.

### Arbitrary USDZ models

USDZ files can have wildly different scales and origins.

Before displaying one, hologrammAR:

1. clones the source entity;
2. calculates its recursive visual bounds;
3. centers the visible geometry;
4. determines its largest dimension;
5. scales it to a consistent hologram size.

This lets very different models share the same interaction without manually reauthoring every asset.

### Visual treatment

The current hologram effect is built from RealityKit-supported materials and geometry.

The model uses multiple visual layers to create more definition than a simple transparent blue material:

* translucent blue-white body;
* emissive lighting;
* wireframe detail;
* subtle ghosting;
* scan-style accents.

The surrounding rings use multiple overlapping emissive layers so they read more like lines of light than solid torus geometry.

The model and rings rotate independently and in opposite directions.

## Tuning

Most of the useful visual and interaction tuning lives in:

```text
Services/HologramSceneController.swift
Services/HandPoseClassifier.swift
Services/HandTrackingService.swift
```

Useful values include:

* hologram size;
* palm offset;
* model rotation speed;
* ring rotation speed;
* material opacity;
* emissive intensity;
* hand-open threshold;
* stabilization sample counts.

## Current limitations

This is a proof of concept, not a production interaction system.

Known areas for improvement include:

* The hologram effect is still an approximation rather than a true procedural surface shader.
* Scan-line effects are currently created with RealityKit-supported geometry/material techniques.
* Arbitrary USDZ assets can vary dramatically in topology and may not all respond equally well to wireframe rendering.
* The hand-pose classifier is intentionally simple and has only been designed around the open-palm / closed-hand interaction.
* The visual anchor offset may need minor tuning for different hand positions.
* There is currently no model-selection UI; models are chosen randomly.

## Why?

Mostly because opening your hand and having a tiny glowing object materialize over your palm is the kind of interaction spatial computing is made for.

It also makes a useful little test bed for:

* visionOS hand tracking;
* RealityKit hand anchors;
* custom gesture classification;
* USDZ normalization;
* mixed immersive spaces;
* stylized RealityKit rendering.

## Contributing

This is an experiment, so issues, forks, visual-effect ideas, and improvements are welcome.

If you build a better hologram material, improve the hand classifier, or find an interesting use for the interaction, I'd love to see it!
