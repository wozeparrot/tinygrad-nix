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
  torch,
  clang,
  pytest-xdist,
  hypothesis,
  pytestCheckHook,
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
      # copy extra into core tinygrad
      cp -r ${inputs.tinygrad}/extra ./tinygrad/

      # recursively find all packages
      paths=$(find tinygrad -type d -name '__pycache__' -prune -o -type d -name 'assets' -prune -o -type d -print)
      # replace / in path with .
      paths=$(echo $paths | sed 's/\//\./g')
      # write paths to file
      for path in $paths; do
        echo "$path" >> packages.txt
      done
      cat packages.txt

      # patch packages in setup.py to read from the file
      substituteInPlace setup.py --replace-fail "packages = ['tinygrad', 'tinygrad.runtime.autogen', 'tinygrad.codegen', 'tinygrad.nn', 'tinygrad.renderer', 'tinygrad.engine'," "packages=open('./packages.txt').read().splitlines(),"
      substituteInPlace setup.py --replace-fail "'tinygrad.runtime', 'tinygrad.runtime.support', 'tinygrad.runtime.support.am', 'tinygrad.runtime.graph', 'tinygrad.shape']," ""

      # patch all references to extra to tinygrad.extra
      files=$(find tinygrad -type f -name '__init__.py' -prune -o -type f -name '*.py' -print)
      for file in $files; do
        substituteInPlace "$file" --replace "extra." "tinygrad.extra."
      done

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
      substituteInPlace tinygrad/runtime/autogen/comgr.py --replace-fail "/opt/rocm/lib/libamd_comgr.so" "${rocmPackages.rocm-comgr}/lib/libamd_comgr.so"
      substituteInPlace tinygrad/runtime/support/compiler_hip.py --replace-fail "/opt/rocm/include" "${rocmPackages.clr}/include"

      # patch correct path to hsa
      substituteInPlace tinygrad/runtime/autogen/hsa.py --replace-fail "os.getenv('ROCM_PATH')+'/lib/libhsa-runtime64.so' if os.getenv('ROCM_PATH') else ctypes.util.find_library('hsa-runtime64')" "'${rocmPackages.rocm-runtime}/lib/libhsa-runtime64.so'"
    '')
    + (lib.optionalString cudaSupport ''
      # patch correct path to cuda
      substituteInPlace tinygrad/runtime/autogen/nvrtc.py --replace-fail "ctypes.util.find_library('nvrtc')" "'${cudaPackages.cuda_nvrtc.lib}/lib/libnvrtc.so'"
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
    torch
    clang
    pytest-xdist
    hypothesis
    pytestCheckHook
  ];

  preCheck = ''
    export HOME=$(mktemp -d)
    export CLANG=1
  '';

  pytestFlagsArray = [
    "test/test_ops.py"
  ];

  disabledTests = [
    "test_gemm_fp16"
  ];
}
