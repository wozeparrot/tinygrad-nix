{
  lib,
  inputs,
  stdenv,
  buildPythonPackage,
  addDriverRunpath,
  ocl-icd,
  llvmPackages_latest,
  rocmPackages,
  cudaPackages,
  setuptools,
  wheel,
  numpy,
  tqdm,
  torch,
  clang,
  gcc,
  pytest-xdist,
  hypothesis,
  pytestCheckHook,
  writableTmpDirAsHomeHook,
  llvmSupport ? true,
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
      substituteInPlace setup.py --replace-fail "packages = ['tinygrad', 'tinygrad.runtime.autogen', 'tinygrad.runtime.autogen.am', 'tinygrad.codegen', 'tinygrad.nn'," "packages=open('./packages.txt').read().splitlines(),"
      substituteInPlace setup.py --replace-fail "'tinygrad.renderer', 'tinygrad.engine', 'tinygrad.viz', 'tinygrad.runtime', 'tinygrad.runtime.support', 'tinygrad.schedule'," ""
      substituteInPlace setup.py --replace-fail "'tinygrad.runtime.support.am', 'tinygrad.runtime.graph', 'tinygrad.shape', 'tinygrad.uop', 'tinygrad.codegen.opt'," ""
      substituteInPlace setup.py --replace-fail "'tinygrad.runtime.support.nv', 'tinygrad.apps']," ""

      # patch all references to extra to tinygrad.extra
      files=$(find tinygrad -type f -name '__init__.py' -prune -o -type f -name '*.py' -print)
      for file in $files; do
        substituteInPlace "$file" --replace "extra." "tinygrad.extra."
      done

      # make viz work
      substituteInPlace tinygrad/viz/serve.py --replace-fail "os.path.dirname(__file__)" '"${inputs.tinygrad}/tinygrad/viz/"'

      # patch libc
      substituteInPlace tinygrad/runtime/autogen/libc.py --replace-fail "ctypes.util.find_library('c')" '"${stdenv.cc.libc}/lib/libc.so.6"'

      # patch gcc
      substituteInPlace tinygrad/runtime/support/system.py --replace-fail "ctypes.util.find_library('atomic')" '"${gcc.cc.lib}/lib/libatomic.so"'
    ''
    + (lib.optionalString llvmSupport ''
      # patch correct path to llvm
      substituteInPlace tinygrad/runtime/support/llvm.py --replace-fail "ctypes.util.find_library('LLVM')" '"${llvmPackages_latest.llvm.lib}/lib/libLLVM.so"'
    '')
    + (lib.optionalString openclSupport ''
      # patch correct path to opencl
      substituteInPlace tinygrad/runtime/autogen/opencl.py --replace-fail "ctypes.util.find_library('OpenCL')" "'${ocl-icd}/lib/libOpenCL.so'"
    '')
    + (lib.optionalString rocmSupport ''
      # patch correct path to hip
      substituteInPlace tinygrad/runtime/autogen/hip.py --replace-fail "os.getenv('ROCM_PATH', '/opt/rocm/')+'/lib/libamdhip64.so'" "'${rocmPackages.clr}/lib/libamdhip64.so'"

      # patch correct path to comgr
      substituteInPlace tinygrad/runtime/autogen/comgr.py --replace-fail "/opt/rocm/lib/libamd_comgr.so" "${rocmPackages.rocm-comgr}/lib/libamd_comgr.so"
      substituteInPlace tinygrad/runtime/support/compiler_amd.py --replace-fail "/opt/rocm/include" "${rocmPackages.clr}/include"

      # patch correct path to hsa
      substituteInPlace tinygrad/runtime/autogen/hsa.py --replace-fail "os.getenv('ROCM_PATH')+'/lib/libhsa-runtime64.so' if os.getenv('ROCM_PATH') else ctypes.util.find_library('hsa-runtime64')" "'${rocmPackages.rocm-runtime}/lib/libhsa-runtime64.so'"
    '')
    + (lib.optionalString cudaSupport ''
      # patch correct path to cuda
      substituteInPlace tinygrad/runtime/autogen/nvrtc.py --replace-fail "ctypes.util.find_library('nvrtc')" "'${lib.getLib cudaPackages.cuda_nvrtc}/lib/libnvrtc.so'"
      substituteInPlace tinygrad/runtime/autogen/cuda.py --replace-fail "ctypes.util.find_library('cuda')" "'${addDriverRunpath.driverLink}/lib/libcuda.so'"

      # patch correct path to include
      substituteInPlace tinygrad/runtime/support/compiler_cuda.py \
        --replace-fail \
        '"-I/usr/local/cuda/include", "-I/usr/include", "-I/opt/cuda/include"' \
        '"-I${lib.getDev cudaPackages.cuda_cudart}/include/"'
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
    pytestCheckHook
    writableTmpDirAsHomeHook

    torch
    clang
    pytest-xdist
    hypothesis
  ];

  preCheck = ''
    export CPU=1
    export CC=${clang}/bin/clang
  '';

  pytestFlagsArray = [
    "test/test_ops.py"
  ];

  disabledTests = [
    "test_gemm_fp16"
    "TestOpsBFloat16"
    "test_div_int"
  ];
}
