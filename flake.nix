{
  description = "supermd";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zon2nix = {
      url = "github:jcollie/zon2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };
  };

  outputs = {
    nixpkgs,
    flake-utils,
    zon2nix,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        packages = {
          supermd = let
            zig_hook = pkgs.zig_0_14.hook.overrideAttrs {
              zig_default_flags = "-Dcpu=baseline -Doptimize=ReleaseFast --color off";
            };
          in
            pkgs.stdenv.mkDerivation {
              name = "supermd";
              version = "0.0.0";
              outputs = [
                "out"
                "tree_sitter"
              ];
              src = ./.;
              nativeBuildInputs = [zig_hook];
              zigBuildFlags = [
                "--system"
                "${pkgs.callPackage ./build.zig.zon.nix {}}"
              ];
              postInstall = ''
                mkdir $tree_sitter
                cp -R tree-sitter/supermd $tree_sitter/supermd
                cp -R tree-sitter/supermd-inline $tree_sitter/supermd_inline
              '';
            };
        };
        devShells.default = pkgs.mkShell {
          buildInputs = [
            pkgs.zig_0_14
            zon2nix.packages.${system}.zon2nix
          ];
        };
      }
    );
}
