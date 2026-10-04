# RageBlox

**RageBlox** is an independent, creator-focused game platform and development environment built around the goal of making game creation, publishing, multiplayer, and playing feel familiar, accessible, and deeply integrated.

The long-term goal is a complete platform: an engine, editor, runtime, multiplayer stack, creator tools, player-facing platform, and the services needed to create and play user-made experiences.

## Vision

> **Give creators a powerful, approachable platform where they can build, publish, share, and play interactive experiences.**

RageBlox is designed around a highly integrated workflow where the editor and runtime work together instead of forcing creators to assemble dozens of unrelated tools.

## Planned Platform

### RageBlox Engine
- 3D rendering
- Physics and collision
- Scene and object systems
- Transform and hierarchy systems
- Lighting and materials
- Audio
- Particles and visual effects
- Animation
- Character controllers
- Cameras and input
- Asset loading and management
- Serialization and persistence
- Multiplayer networking and replication
- Client/server architecture
- Scripting

### RageBlox Studio
- Scene and world editing
- Explorer-style object hierarchy
- Properties and inspectors
- Building with parts and models
- Terrain and environment tools
- Material and appearance editing
- Lighting tools
- Animation tools
- Asset importing
- Script editing
- Testing and play modes
- Multiplayer testing
- Publishing and project management

### RageBlox Runtime
- Client runtime
- Dedicated/server runtime
- Authoritative gameplay systems
- Replicated objects and state
- Player and character systems
- User interfaces
- Input and controls
- Audio and visual effects
- Secure client/server communication

### RageBlox Platform
- User accounts
- Profiles
- Experiences
- Publishing
- Public and private servers
- Experience discovery and search
- Friends and social features
- Avatar customization
- Creator permissions
- Collaboration
- Player-created content
- Moderation and safety systems
- Developer and creator services

## Creator Workflow

Creators should eventually be able to:

1. Create an experience.
2. Build a world.
3. Add and configure objects.
4. Write gameplay logic.
5. Test locally or with other players.
6. Publish the experience.
7. Host multiplayer sessions.
8. Update the experience without rebuilding the entire platform.

These workflows will be treated as first-class parts of the architecture.

## Original Work

RageBlox is an independent project.

RageBlox-specific code, systems, branding, artwork, models, sounds, animations, UI assets, and other original content will be created independently or used under licenses that explicitly permit their use.

RageBlox does not rely on proprietary source code or proprietary assets from other platforms.

## Development Status

RageBlox is under active development.

The current repository contains an existing engine/editor foundation that is being evaluated, reworked, and expanded toward the RageBlox vision. Major systems will be audited before large-scale feature development so the architecture can support the long-term platform instead of accumulating disconnected features.

Expect substantial changes while the foundation is being developed.

## Project Structure

The repository currently contains the major pieces of the platform foundation:

- **Engine / runtime** — rendering, physics, objects, networking, scripting, and gameplay infrastructure
- **Studio / editor** — creation and development workflows
- **Web / platform services** — online and creator functionality
- **Documentation** — technical and creator-facing documentation
- **Scripts** — development and setup tooling

The architecture will continue to evolve as RageBlox moves toward the complete platform.

## Licensing

See [LICENSE.txt](LICENSE.txt) for the licenses that apply to the existing repository.

Code and included assets may have different licensing terms. Do not assume that every asset in the repository has the same license as the source code.

New RageBlox-original assets and code will have their licensing documented appropriately.

## Development Principles

RageBlox is being developed with an emphasis on:

- Strong foundational architecture
- Multiplayer correctness
- Security against untrusted clients
- Creator usability
- Cross-platform compatibility
- Reliable serialization and publishing
- Maintainable systems
- Original code and content
- Compatibility between editor, runtime, and platform services

## Roadmap

The long-term roadmap includes:

- [ ] Core engine foundation
- [ ] Robust object/component hierarchy
- [ ] Building and modeling tools
- [ ] Character and humanoid systems
- [ ] Physics and interaction systems
- [ ] Scripting environment
- [ ] Studio editor workflows
- [ ] Client/server networking
- [ ] Replication and remote communication
- [ ] Asset pipeline
- [ ] Experience serialization and publishing
- [ ] Accounts and profiles
- [ ] Multiplayer servers
- [ ] Experience discovery
- [ ] Avatar system
- [ ] Social systems
- [ ] Creator collaboration
- [ ] Moderation and safety infrastructure
- [ ] Creator/developer services
- [ ] Cross-platform support

This roadmap is intentionally broad. Individual systems will be broken down and implemented after the underlying architecture has been audited.

---

**RageBlox** — build it, publish it, play it.
