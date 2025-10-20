{
  description = "ATProtocol and BlueSky SDK and bot framework for Elixir";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05-small";
  inputs.elixir-overlay.url = "github:zoedsoupe/elixir-overlay";

  outputs = {
    nixpkgs,
    elixir-overlay,
    ...
  }: let
    inherit (nixpkgs.lib) genAttrs;
    inherit (nixpkgs.lib.systems) flakeExposed;
    forAllSystems = f:
      genAttrs flakeExposed (system:
        f (import nixpkgs {
          inherit system;
          overlays = [elixir-overlay.overlays.default];
        }));
  in {
    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        name = "proto-rune-dev";
        packages = with pkgs; [erlang_28 (elixir-with-otp erlang_28).latest aider-chat];
      };
    });
  };
}
