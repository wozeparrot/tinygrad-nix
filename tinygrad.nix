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

      sed -i '/^\s*packages = \[/,/^\s*\]/c\
      packages = {find = {where = ["."], include = ["tinygrad*"], exclude = ["tinygrad.assets*", "tinygrad.installer*"]}}' pyproject.toml

      # patch all references to extra to tinygrad.extra
      files=$(find tinygrad -type f -name '__init__.py' -prune -o -type f -name '*.py' -print)
      for file in $files; do
        substituteInPlace "$file" --replace "extra." "tinygrad.extra."
      done

      # make viz work
      substituteInPlace tinygrad/viz/serve.py --replace-fail "os.path.dirname(__file__)" '"${inputs.tinygrad}/tinygrad/viz/"'

      # patch libc
      substituteInPlace tinygrad/runtime/autogen/libc.py --replace-fail "find_library('c')" '"${stdenv.cc.libc}/lib/libc.so.6"'

      # patch gcc
      substituteInPlace tinygrad/runtime/support/system.py --replace-fail "ctypes.util.find_library('atomic')" '"${gcc.cc.lib}/lib/libatomic.so"'
    ''
    + (lib.optionalString llvmSupport ''
      # patch correct path to llvm
      substituteInPlace tinygrad/runtime/support/llvm.py --replace-fail "ctypes.util.find_library('LLVM')" '"${llvmPackages_latest.llvm.lib}/lib/libLLVM.so"'
    '')
    + (lib.optionalString openclSupport ''
      # patch correct path to opencl
      substituteInPlace tinygrad/runtime/autogen/opencl.py --replace-fail "find_library('OpenCL')" "'${ocl-icd}/lib/libOpenCL.so'"
    '')
    + (lib.optionalString rocmSupport ''
      # patch correct path to hip
      substituteInPlace tinygrad/runtime/autogen/hip.py --replace-fail "os.getenv('ROCM_PATH', '/opt/rocm')" "'${rocmPackages.clr}'"

      # patch correct path to comgr
      substituteInPlace tinygrad/runtime/autogen/comgr.py --replace-fail "os.getenv('ROCM_PATH', '/opt/rocm')" "'${rocmPackages.rocm-comgr}'"
      substituteInPlace tinygrad/runtime/support/compiler_amd.py --replace-fail "/opt/rocm/include" "${rocmPackages.clr}/include"

      # patch correct path to hsa
      substituteInPlace tinygrad/runtime/autogen/hsa.py --replace-fail "os.getenv('ROCM_PATH', '/opt/rocm')" "'${rocmPackages.rocm-runtime}'"
    '')
    + (lib.optionalString cudaSupport ''
      # patch correct path to cuda
      substituteInPlace tinygrad/runtime/autogen/nvrtc.py --replace-fail "find_library('nvrtc')" "'${lib.getLib cudaPackages.cuda_nvrtc}/lib/libnvrtc.so'"
      substituteInPlace tinygrad/runtime/autogen/cuda.py --replace-fail "find_library('cuda')" "'${addDriverRunpath.driverLink}/lib/libcuda.so'"

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
    llvmPackages_latest.clang-unwrapped
    pytest-xdist
    hypothesis
  ];

  preCheck = ''
    export CPU=1
    export CC=${llvmPackages_latest.clang-unwrapped}/bin/clang
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
