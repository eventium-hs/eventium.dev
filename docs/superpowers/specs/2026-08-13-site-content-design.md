# eventium.dev Site Content — Design

**Date:** 2026-08-13
**Status:** Approved

## Goal

Fill the eventium.dev website (currently a bare Hakyll scaffold: landing page +
two empty docs stubs) with substantive, accurate content: documentation guides
and example walkthroughs. Source material is two in-depth blog posts, the
library source (v0.6.0), the library's `docs/architecture.md`, and three worked
example apps (counter-cli, cafe, bank).

## Decisions

- **Structure:** Docs + Examples. The two blog posts are folded into evergreen
  docs guides (no separate dated "Articles" section). Examples get their own
  section.
- **Depth:** Core — getting-started + the main concept guides drawn from the
  blog posts + an examples index. Newer/edge topics (schema evolution,
  telemetry) get brief pointers, not full concept pages.
- **Accuracy:** Content reflects the current library, **v0.6.0**. Every Haskell
  snippet is verified against current source before shipping. Repo links use
  `eventium-hs/eventium`.
- **Presentation:** Content-first, light polish. Keep the existing clean CSS;
  add a docs sidebar layout, syntax-highlighting CSS, and an Examples nav link.

## Information Architecture

Header nav: **Docs**, **Examples**, Hackage, GitHub. Landing page reworded to
funnel into Docs and Examples.

### Docs — `content/docs/` (8 pages)

| Page | Content |
|---|---|
| `index.md` | Docs home: what Eventium is, the mental model, a map of the guides. |
| `getting-started.md` | Install (`eventium-core` + a backend), a runnable minimal counter (events → command → projection → handler → in-memory store), expected output, next steps. |
| `concepts.md` | Event Sourcing & CQRS — the conceptual skeleton. |
| `projections.md` | `Projection{seed,eventHandler}`, `getLatestStreamProjection`, folds, testing, codec/lenient projections. |
| `command-handlers.md` | `CommandHandler{decide,projection}`, `applyCommandHandler`, optimistic concurrency (`ExpectedPosition`), `CommandHandlerError`. |
| `process-managers.md` | `ProcessManager{projection,react}`, `ProcessManagerEffect`, compensation/saga, dispatcher. |
| `read-models.md` | `ReadModel{…}`, in-memory vs persisted, checkpoints, `runReadModel`/`rebuildReadModel`/`combineReadModels`, resilient subscriptions. |
| `internals.md` | Design & Internals (from post 2): single-table + gap-free global sequence, records-not-typeclasses, metadata pipeline, snapshotting; brief pointers to schema evolution and telemetry. |

### Examples — `content/examples/` (4 pages)

| Page | Content |
|---|---|
| `index.md` | The three examples, the counter → cafe → bank progression, how to run, link to `eventium-hs/examples`. |
| `counter-cli.md` | The ~100-line in-memory counter — four core primitives. |
| `cafe.md` | Café tab: SQLite persistence, explicit error type, cross-process polling read model. |
| `bank.md` | Full CQRS: multi-aggregate, transfer process manager with compensation, dual read models, TH composition. |

## Infrastructure (light polish)

- `site.hs`: add route `content/examples/*.md` → `examples/*.html`.
- New `templates/docs.html`: shared layout with a left sidebar listing all
  Docs + Examples pages (current page highlighted). Used for docs/examples;
  landing keeps `default.html`.
- `css/main.css`: add sidebar layout + syntax-highlighting token CSS (Pandoc /
  skylighting classes) for both light and dark themes.
- Header nav gains an **Examples** link.

## Verification

- Every Haskell snippet checked against v0.6.0 source (`eventium-core` /
  backends): signatures, module names, dot-syntax.
- `just build` renders the whole site cleanly; all internal links resolve;
  spot-check rendered pages via `just run`.

## Out of scope

- Full design refresh of the visual theme.
- Dedicated concept pages for schema evolution / telemetry (pointers only).
- A dated blog/articles section.
