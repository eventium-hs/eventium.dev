# List available commands
help:
    @just --list

# Build the site into _site/
build:
    cabal run site -- build

# Watch sources and serve at http://localhost:8000
run:
    cabal run site -- watch

# Open the site in a browser
open:
    open http://localhost:8000

# Remove generated artifacts (_site, _cache)
clean:
    cabal run site -- clean

# Format Nix files
format:
    nix fmt
