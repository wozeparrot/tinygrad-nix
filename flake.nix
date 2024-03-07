{
  description = "auto updating tinygrad overlay";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # pull in the rocm6 pr until it's merged
    nixpkgs-rocm6.url = "github:mschwaig/nixpkgs/rocm-6.0.2";

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
      rocm6 = import inputs.nixpkgs-rocm6 {system = final.system;};

      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (
            python-final: python-prev: {
              tinygrad = python-prev.buildPythonPackage {
                pname = "tinygrad";
                version = inputs.tinygrad.shortRev;
                pyproject = true;
                src = inputs.tinygrad;

                patches = [
                  # ./hip.patch
                ];

                postPatch = ''
                  # patch correct path to opencl
                  substituteInPlace tinygrad/runtime/autogen/opencl.py --replace-fail "ctypes.util.find_library('OpenCL')" "'${prev.ocl-icd}/lib/libOpenCL.so'"

                  # patch correct path to hip
                  substituteInPlace tinygrad/runtime/autogen/hip.py --replace-fail "/opt/rocm/lib/libamdhip64.so" "${final.rocm6.rocmPackages.clr}/lib/libamdhip64.so"

                  # patch correct path to comgr
                  substituteInPlace tinygrad/runtime/autogen/comgr.py --replace-fail "/opt/rocm/lib/libamd_comgr.so" "${final.rocm6.rocmPackages.rocm-comgr}/lib/libamd_comgr.so"

                  # patch correct path to hsa
                  substituteInPlace tinygrad/runtime/autogen/hsa.py --replace-fail "/opt/rocm/lib/libhsa-runtime64.so" "${final.rocm6.rocmPackages.rocm-runtime}/lib/libhsa-runtime64.so"
                '';

                nativeBuildInputs = with python-prev; [
                  setuptools
                  wheel
                ];

                propagatedBuildInputs = with python-prev; [
                  numpy
                  tqdm
                ];

                doCheck = false;
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
        packages = rec {
          inherit (pkgs.python3Packages) tinygrad;
          default = tinygrad;
        };
      }
    )
    // {
      overlays.default = overlay;
    };
}
