{
  description = "auto updating tinygrad overlay";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    tinygrad = {
      url = "github:tinygrad/tinygrad";
      flake = false;
    };
  };

  outputs = inputs @ {
    nixpkgs,
    flake-utils,
    ...
  }: let
    overlay = final: prev: {
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (
            python-final: python-prev: rec {
              tinygrad = python-final.callPackage ./tinygrad.nix {
                inherit inputs;
              };
              tinygradWithRocm = tinygrad.override {
                rocmSupport = true;
              };
              tinygradWithCuda = tinygrad.override {
                cudaSupport = true;
              };
              tinygradFull = tinygrad.override {
                rocmSupport = true;
                cudaSupport = true;
                openclSupport = true;
              };
            }
          )
        ];
    };
  in
    flake-utils.lib.eachDefaultSystem
    (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [overlay];
          config.allowUnfree = true;
        };
      in {
        packages = rec {
          inherit (pkgs.python312Packages) tinygrad tinygradWithRocm tinygradWithCuda tinygradFull;
          default = tinygradFull;
        };
      }
    )
    // {
      overlays.default = overlay;
    };
}
