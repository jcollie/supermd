# SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
# SPDX-License-Identifier: MIT

{
  description = "SuperMD: the Markdown dialect of the Zine static site generator";

  inputs = {
    nixpkgs = {
      url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
    };
    zon2nix = {
      url = "github:jcollie/zon2nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  outputs =
    {
      nixpkgs,
      zon2nix,
      ...
    }:
    let
      inherit (nixpkgs) lib;
      makePackages =
        system:
        import nixpkgs {
          inherit system;
        };
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      # The grammars' queries come from nvim-treesitter's markdown ones, so
      # Helix gets its own copies in queries/helix/: the captures renamed to
      # the scopes a Helix theme styles -- following Helix's own markdown and
      # markdown.inline queries -- and include-unnamed-children added to
      # every injection, without which Helix leaves an injected node's
      # unnamed children (an inline's `*`, `[`, `]`) out of the text it
      # hands the injected parser.
      helixQueries = renames: ''
        mkdir -p $out/queries/helix
        sed -E ${
          lib.concatMapAttrsStringSep " " (
            from: to: lib.escapeShellArg "-es/@${lib.escapeRegex from}\\b/@${to}/g"
          ) renames
        } queries/highlights.scm > $out/queries/helix/highlights.scm
        sed -E 's/\(#set! injection\.language "([^"]+)"\)\)$/(#set! injection.language "\1") (#set! injection.include-unnamed-children))/' \
          queries/injections.scm > $out/queries/helix/injections.scm
      '';

      grammar =
        pkgs: language: dir: renames:
        pkgs.tree-sitter.buildGrammar {
          inherit language;
          version = "0.1.0";
          src = lib.fileset.toSource {
            root = dir;
            fileset = lib.fileset.unions [
              (dir + "/grammar.js")
              (dir + "/queries")
              (dir + "/src")
            ];
          };
          postInstall = helixQueries renames;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = makePackages system;
        in
        rec {
          supermd = pkgs.callPackage ./package.nix { };
          default = supermd;
          # The Zig dependencies on their own, laid out as `zig build
          # --system` wants them, for a build that is not the package's.
          zig-deps = pkgs.callPackage ./build.zig.zon.nix { };
          # The grammars compiled for an editor, with their queries beside
          # them and Helix's in queries/helix/.
          tree-sitter-supermd = grammar pkgs "supermd" ./tree-sitter/supermd {
            "text.title" = "markup.heading";
            "text.literal" = "markup.raw.block";
            "text.uri" = "markup.link.url";
            "text.reference" = "markup.link.label";
          };
          tree-sitter-supermd-inline = grammar pkgs "supermd_inline" ./tree-sitter/supermd-inline {
            "text.literal" = "markup.raw.inline";
            "text.emphasis" = "markup.italic";
            "text.strong" = "markup.bold";
            "text.uri" = "markup.link.url";
            "text.reference" = "markup.link.text";
            "string.escape" = "constant.character.escape";
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = makePackages system;
        in
        {
          default = pkgs.mkShell {
            name = "supermd";
            nativeBuildInputs = [
              pkgs.zig_0_17
              # zon2nix shells out to `zig env`, so give it this Zig rather
              # than whichever one the caller has.
              (pkgs.symlinkJoin {
                name = "zon2nix";
                paths = [ zon2nix.packages.${system}.zon2nix ];
                nativeBuildInputs = [ pkgs.makeWrapper ];
                postBuild = ''
                  wrapProgram $out/bin/zon2nix \
                    --prefix PATH : ${lib.makeBinPath [ pkgs.zig_0_17 ]}
                '';
              })
            ];
          };
        }
      );
    };
}
