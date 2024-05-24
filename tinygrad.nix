{
  lib,
  inputs,
  buildPythonPackage,

  ocl-icd,
  rocmPackages,

  setuptools,
  wheel,
  numpy,
  tqdm,

  hypothesis,
  torch,
  pytestCheckHook,
  llvmPackages_latest,

  enableOpenCL ? true,
  enableRocm ? false,
}:
buildPythonPackage {
  pname = "tinygrad";
  version = inputs.tinygrad.shortRev;
  pyproject = true;
  src = inputs.tinygrad;

  postPatch =
    (lib.optionalString enableOpenCL ''
      # patch correct path to opencl
      substituteInPlace tinygrad/runtime/autogen/opencl.py --replace-fail "ctypes.util.find_library('OpenCL')" "'${ocl-icd}/lib/libOpenCL.so'"
    '')
    + (lib.optionalString enableRocm ''
      # patch correct path to hip
      substituteInPlace tinygrad/runtime/autogen/hip.py --replace-fail "os.getenv('ROCM_PATH', '/opt/rocm/')+'/lib/libamdhip64.so'" "'${rocmPackages.clr}/lib/libamdhip64.so'"

      # patch correct path to comgr
      substituteInPlace tinygrad/runtime/autogen/comgr.py --replace-fail "os.getenv('ROCM_PATH')+'/lib/libamd_comgr.so' if os.getenv('ROCM_PATH') else ctypes.util.find_library('amd_comgr')" "'${rocmPackages.rocm-comgr}/lib/libamd_comgr.so'"
      substituteInPlace tinygrad/runtime/driver/hip_comgr.py --replace-fail "/opt/rocm/include" "${rocmPackages.clr}/include"

      # patch correct path to hsa
      substituteInPlace tinygrad/runtime/autogen/hsa.py --replace-fail "os.getenv('ROCM_PATH')+'/lib/libhsa-runtime64.so' if os.getenv('ROCM_PATH') else ctypes.util.find_library('hsa-runtime64')" "'${rocmPackages.rocm-runtime}/lib/libhsa-runtime64.so'"
    '');

  nativeBuildInputs = [
    setuptools
    wheel
  ];

  propagatedBuildInputs = [
    numpy
    tqdm
  ];

  pythonImportsCheck = ["tinygrad"];

  nativeCheckInputs = [
    hypothesis
    torch
    pytestCheckHook
    llvmPackages_latest.clang
  ];

  preCheck = ''
    export HOME=$(mktemp -d)
    export CLANG=1
  '';

  pytestFlagsArray = [
    "test/test_ops.py"
  ];
}
