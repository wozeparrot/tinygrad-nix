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
                pyproject = true;
                src = inputs.tinygrad;

                postPatch = ''
                  # patch correct path to opencl
                  substituteInPlace tinygrad/runtime/autogen/opencl.py --replace-fail "ctypes.util.find_library('OpenCL')" "'${prev.ocl-icd}/lib/libOpenCL.so'"

                  # patch correct path to hip
                  substituteInPlace tinygrad/runtime/autogen/hip.py --replace-fail "os.getenv('ROCM_PATH', '/opt/rocm/')+'/lib/libamdhip64.so'" "'${final.rocmPackages.clr}/lib/libamdhip64.so'"

                  # patch correct path to comgr
                  substituteInPlace tinygrad/runtime/autogen/comgr.py --replace-fail "os.getenv('ROCM_PATH')+'/lib/libamd_comgr.so' if os.getenv('ROCM_PATH') else ctypes.util.find_library('amd_comgr')" "'${final.rocmPackages.rocm-comgr}/lib/libamd_comgr.so'"
                  substituteInPlace tinygrad/runtime/driver/hip_comgr.py --replace-fail "/opt/rocm/include" "${final.rocmPackages.clr}/include"

                  # patch correct path to hsa
                  substituteInPlace tinygrad/runtime/autogen/hsa.py --replace-fail "os.getenv('ROCM_PATH')+'/lib/libhsa-runtime64.so' if os.getenv('ROCM_PATH') else ctypes.util.find_library('hsa-runtime64')" "'${final.rocmPackages.rocm-runtime}/lib/libhsa-runtime64.so'"
                '';

                nativeBuildInputs = with python-prev; [
                  setuptools
                  wheel
                ];

                propagatedBuildInputs = with python-prev; [
                  numpy
                  tqdm
                ];

                pythonImportsCheck = ["tinygrad"];

                nativeCheckInputs = with python-final; [
                  hypothesis
                  librosa
                  onnx
                  pillow
                  pytest-xdist
                  pytestCheckHook
                  safetensors
                  sentencepiece
                  tiktoken
                  torch
                  transformers
                  pkgs.llvmPackages_latest.clang
                ];

                preCheck = ''
                  export HOME=$(mktemp -d)
                  export CLANG=1
                '';

                pytestFlagsArray = [
                  "-n auto"
                  "test/test_ops.py"
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
        packages = rec {
          inherit (pkgs.python312Packages) tinygrad;
          default = tinygrad;
        };
      }
    )
    // {
      overlays.default = overlay;
    };
}
