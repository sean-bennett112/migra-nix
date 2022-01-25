{
  description = "A flake wrapping pgquarrel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    poetry2nix.url = "github:nix-community/poetry2nix";
    migra-src = {
      url = "github:djrobstep/migra";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, poetry2nix, migra-src }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ poetry2nix.overlay ];
        };
        migra = pkgs.poetry2nix.mkPoetryApplication {
          projectDir = migra-src;
          # Required due to `https://github.com/nix-community/poetry2nix/issues/435`
          #
          # It looks like there's still something wrong after the fix from
          # `https://github.com/nix-community/poetry2nix/pull/482`, still need to
          # debug.
          src = migra-src;
          # Required due to `https://github.com/djrobstep/sqlbag/issues/8`
          # Already fixed upstream, but `migra` still depends on an old version
          # of `sqlbag`.
          overrides = pkgs.poetry2nix.overrides.withDefaults (final: prev: {
            sqlbag = prev.sqlbag.overridePythonAttrs (old: {
              propagatedBuildInputs =
                [ final.packaging final.six final.sqlalchemy ];
              postPatch = ''
                sed -i 's#pathlib#packaging#' setup.py
              '';
            });
          });
        };
      in {
        overlay = final: prev: { inherit migra; };
        packages."${system}".migra = migra;
        defaultPackage."${system}" = migra;
        devShell = pkgs.mkShell { buildInputs = [ migra ]; };
      });
}
