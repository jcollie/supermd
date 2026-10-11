# SPDX-FileCopyrightText: © 2026 Jeffrey C. Ollie <jeff@ocjtech.us>
# SPDX-License-Identifier: MIT

{
  lib,
  stdenv,
  callPackage,
  zig_0_17,
}:
let
  # Generated from build.zig.zon by zon2nix; regenerate with
  #   nix develop -c zon2nix --17 --nix=build.zig.zon.nix build.zig.zon
  zigDeps = callPackage ./build.zig.zon.nix { };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "supermd";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./build.zig
      ./build.zig.zon
      ./src
    ];
  };

  nativeBuildInputs = [ zig_0_17 ];

  zigBuildFlags = [
    "--system"
    "${zigDeps}"
  ];
  # The check phase assembles its own flags rather than reusing the build's,
  # so without this `zig build test` runs without --system and tries to fetch.
  zigCheckFlags = finalAttrs.zigBuildFlags;
  doCheck = true;

  meta = {
    description = "SuperMD, the Markdown dialect of the Zine static site generator";
    homepage = "https://github.com/kristoff-it/supermd";
    license = lib.licenses.mit;
  };
})
