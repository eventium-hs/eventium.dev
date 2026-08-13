# eventium.dev

The website for [Eventium](https://github.com/eventium-hs/eventium) — the Haskell
event sourcing library. Built with [Hakyll](https://jaspervdj.be/hakyll/) and
Nix, deployed to GitHub Pages.

## Development

Prerequisites: Nix (with flakes) + direnv. Entering the directory auto-loads the
dev shell via `.envrc`.

```
just run      # watch sources and serve at http://localhost:8000
just build    # build the site into _site/
just clean    # remove generated artifacts
just format   # format Nix files
```

## Deployment

Pushing to `master` triggers `.github/workflows/deploy.yml`, which runs
`nix build` and publishes the result to GitHub Pages. The custom domain
`eventium.dev` is configured via `static/CNAME`.
