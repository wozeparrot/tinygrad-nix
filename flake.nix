{
  description = "auto updating tinygrad overlay";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    gpuctypes = {
      url = "github:tinygrad/gpuctypes";
      flake = false;
    };
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
              gpuctypes = python-prev.buildPythonPackage {
                pname = "gpuctypes";
                version = inputs.gpuctypes.shortRev;
                src = inputs.gpuctypes;

                postPatch = ''
                  substituteInPlace setup.py --replace "ctypes.util.find_library('OpenCL')" "\"${prev.ocl-icd}/lib/libOpenCL.so\""
                '';

                doCheck = false;
              };
              tinygrad = python-prev.buildPythonPackage {
                pname = "tinygrad";
                version = inputs.tinygrad.shortRev;
                src = inputs.tinygrad;
                doCheck = false;
                propagatedBuildInputs = with python-prev; [
                  gpuctypes
                  numpy
                  tqdm
                ];
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
        };
      in {
        packages.default = pkgs.python3Packages.tinygrad;
      }
    )
    // {
      overlays.default = overlay;
    };
}
