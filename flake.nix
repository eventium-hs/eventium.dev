{
  description = "eventium.dev — the Eventium website, built with Hakyll";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs
          [
            "x86_64-linux"
            "aarch64-linux"
            "x86_64-darwin"
            "aarch64-darwin"
          ]
          (
            system:
            f {
              pkgs = nixpkgs.legacyPackages.${system};
            }
          );
    in
    {
      packages = forAllSystems (
        { pkgs }:
        let
          # The Hakyll site generator, built from the local cabal project.
          generator = pkgs.haskellPackages.callCabal2nix "eventium-site" ./. { };
        in
        {
          inherit generator;

          # Run the generator to produce the static site in $out.
          default = pkgs.stdenv.mkDerivation {
            name = "eventium-dev-site";
            src = ./.;

            nativeBuildInputs = [ generator ];

            # Hakyll/pandoc require a UTF-8 locale to read content files.
            LANG = "C.UTF-8";
            LC_ALL = "C.UTF-8";

            buildPhase = ''
              site build
            '';

            installPhase = ''
              cp -r _site $out
            '';

            dontFixup = true;
          };
        }
      );

      formatter = forAllSystems ({ pkgs }: pkgs.nixfmt-rfc-style);

      devShells = forAllSystems (
        { pkgs }:
        {
          default = pkgs.mkShell {
            packages = [
              (pkgs.haskellPackages.ghcWithPackages (p: [ p.hakyll ]))
              pkgs.cabal-install
              pkgs.just
            ];
          };
        }
      );
    };
}
