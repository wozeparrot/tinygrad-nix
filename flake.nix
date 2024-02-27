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
            python-final: python-prev: {
              tinygrad = python-prev.buildPythonPackage {
                pname = "tinygrad";
                version = inputs.tinygrad.shortRev;
                src = inputs.tinygrad;

                postPatch = ''
                  # patch correct path to opencl
                  substituteInPlace tinygrad/runtime/autogen/opencl.py --replace "ctypes.util.find_library('OpenCL')" "'${prev.ocl-icd}/lib/libOpenCL.so'"

                  # patch correct path to hip
                  substituteInPlace tinygrad/runtime/autogen/hip.py --replace "/opt/rocm/lib/libamdhip64.so" "${prev.rocmPackages.clr}/lib/libamdhip64.so"
                  substituteInPlace tinygrad/runtime/autogen/hip.py --replace "/opt/rocm/lib/libhiprtc.so" "${prev.rocmPackages.clr}/lib/libhiprtc.so"
                  substituteInPlace tinygrad/runtime/autogen/hip.py --replace "hipGetDevicePropertiesR0600" "hipGetDeviceProperties"

                  # patch correct path to comgr
                  substituteInPlace tinygrad/runtime/autogen/comgr.py --replace "/opt/rocm/lib/libamd_comgr.so" "${prev.rocmPackages.rocm-comgr}/lib/libamd_comgr.so"

                  # patch correct path to hsa
                  substituteInPlace tinygrad/runtime/autogen/hsa.py --replace "/opt/rocm/lib/libhsa-runtime64.so" "${prev.rocmPackages.clr}/lib/libhsa-runtime64.so"
                '';

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
