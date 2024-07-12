{
  lib,
  inputs,
  buildPythonPackage,
  ocl-icd,
  rocmPackages,
  cudaPackages,
  setuptools,
  wheel,
  numpy,
  tqdm,
  hypothesis,
  torch,
  pytestCheckHook,
  llvmPackages_latest,
  openclSupport ? true,
  rocmSupport ? false,
  cudaSupport ? false,
}:
buildPythonPackage {
  pname = "tinygrad";
  version = inputs.tinygrad.shortRev;
  pyproject = true;
  src = inputs.tinygrad;

  postPatch =
    ''
      ls
      # move hsa back into core
      mv extra/backends/hsa_driver.py tinygrad/runtime/support/hsa.py
      mv extra/backends/hsa_graph.py tinygrad/runtime/graph/hsa.py
      mv extra/backends/ops_hsa.py tinygrad/runtime/ops_hsa.py
      substituteInPlace tinygrad/engine/jit.py --replace-fail '"CUDA", "NV", "AMD"' '"CUDA", "NV", "AMD", "HSA"'
      substituteInPlace tinygrad/engine/search.py --replace-fail '"CUDA", "AMD", "NV"' '"CUDA", "AMD", "NV", "HSA"'
      # insert line at end of file
      sed -i -e '$aclass HIPRenderer(AMDRenderer): device = "HSA"' tinygrad/renderer/cstyle.py
    ''
    + (lib.optionalString openclSupport ''
      # patch correct path to opencl
      substituteInPlace tinygrad/runtime/autogen/opencl.py --replace-fail "ctypes.util.find_library('OpenCL')" "'${ocl-icd}/lib/libOpenCL.so'"
    '')
    + (lib.optionalString rocmSupport ''
      # patch correct path to hip
      substituteInPlace tinygrad/runtime/autogen/hip.py --replace-fail "os.getenv('ROCM_PATH', '/opt/rocm/')+'/lib/libamdhip64.so'" "'${rocmPackages.clr}/lib/libamdhip64.so'"

      # patch correct path to comgr
      substituteInPlace tinygrad/runtime/autogen/comgr.py --replace-fail "os.getenv('ROCM_PATH')+'/lib/libamd_comgr.so' if os.getenv('ROCM_PATH') else ctypes.util.find_library('amd_comgr')" "'${rocmPackages.rocm-comgr}/lib/libamd_comgr.so'"
      substituteInPlace tinygrad/runtime/driver/hip_comgr.py --replace-fail "/opt/rocm/include" "${rocmPackages.clr}/include"

      # patch correct path to hsa
      substituteInPlace tinygrad/runtime/autogen/hsa.py --replace-fail "os.getenv('ROCM_PATH')+'/lib/libhsa-runtime64.so' if os.getenv('ROCM_PATH') else ctypes.util.find_library('hsa-runtime64')" "'${rocmPackages.rocm-runtime}/lib/libhsa-runtime64.so'"
    '')
    + (lib.optionalString cudaSupport ''
      # patch correct path to cuda
      substituteInPlace tinygrad/runtime/autogen/cuda.py --replace-fail "ctypes.util.find_library('nvrtc')" "'${cudaPackages.cuda_nvrtc.lib}/lib/libnvrtc.so'"
      substituteInPlace tinygrad/runtime/autogen/cuda.py --replace-fail "ctypes.util.find_library('cuda')" "'${cudaPackages.cuda_cudart}/lib/libcuda.so'"
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
