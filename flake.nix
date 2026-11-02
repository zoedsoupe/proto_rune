{
  description = "ATProtocol and BlueSky SDK and bot framework for Elixir";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
  inputs.beam-overlay.url = "github:zeeetech/beam-overlay";

  outputs = {
    nixpkgs,
    beam-overlay,
    ...
  }: let
    inherit (nixpkgs.lib) genAttrs;
    inherit (nixpkgs.lib.systems) flakeExposed;
    forAllSystems = f:
      genAttrs flakeExposed (system:
        f (import nixpkgs {
          inherit system;
          overlays = [beam-overlay.overlays.default];
        }));
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "proto-rune-dev";
        packages = with pkgs; [
          erlang_28
          (pkgs.beam-overlay.mkToolchain {
            elixir.version = "1.20.2";
          })
        ];
      };
    });
  };
}
