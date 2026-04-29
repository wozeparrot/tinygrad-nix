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
  openai,
  z3-solver,
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
      substituteInPlace tinygrad/runtime/autogen/libc.py --replace-fail "'libc', 'c'" '"libc", "${stdenv.cc.libc}/lib/libc.so.6"'

      # patch gcc
      substituteInPlace tinygrad/runtime/support/system.py --replace-fail "ctypes.util.find_library('atomic')" '"${gcc.cc.lib}/lib/libatomic.so"'

      # patch libclang
      sed -i "s|^dll = c\.DLL.*|dll = c.DLL('libclang', '${llvmPackages_latest.libclang.lib}/lib/libclang.so')|" tinygrad/runtime/autogen/libclang.py
    ''
    + (lib.optionalString llvmSupport ''
      # patch correct path to llvm
      sed -i "s|^dll = c\.DLL.*|dll = c.DLL('llvm', '${llvmPackages_latest.llvm.lib}/lib/libLLVM.so')|" tinygrad/runtime/autogen/llvm.py
    '')
    + (lib.optionalString openclSupport ''
      # patch correct path to opencl
      sed -i "s|^dll = c\.DLL.*|dll = c.DLL('opencl', '${ocl-icd}/lib/libOpenCL.so')|" tinygrad/runtime/autogen/opencl.py
    '')
    + (lib.optionalString rocmSupport ''
      # patch correct path to hip
      sed -i "s|^dll = c\.DLL.*|dll = c.DLL('hip', '${rocmPackages.clr}/lib/libamdhip64.so')|" tinygrad/runtime/autogen/hip.py

      # patch correct path to comgr
      sed -i "s|^dll = c\.DLL.*|dll = c.DLL('comgr', '${rocmPackages.rocm-comgr}/lib/libamd_comgr.so')|" tinygrad/runtime/autogen/comgr.py
      substituteInPlace tinygrad/runtime/support/compiler_amd.py --replace-fail "/opt/rocm/include" "${rocmPackages.clr}/include"

      # patch correct path to hsa
      sed -i "s|^dll = c\.DLL.*|dll = c.DLL('hsa', '${rocmPackages.rocm-runtime}/lib/libhsa-runtime64.so')|" tinygrad/runtime/autogen/hsa.py
    '')
    + (lib.optionalString cudaSupport ''
      # patch correct path to cuda
      sed -i "s|^dll = c\.DLL.*|dll = c.DLL('nvrtc', '${lib.getLib cudaPackages.cuda_nvrtc}/lib/libnvrtc.so')|" tinygrad/runtime/autogen/nvrtc.py
      sed -i "s|^dll = c\.DLL.*|dll = c.DLL('cuda', '${addDriverRunpath.driverLink}/lib/libcuda.so')|" tinygrad/runtime/autogen/cuda.py

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
    openai
    z3-solver
  ];

  preCheck = ''
    export DEV=CPU
    export CC=${llvmPackages_latest.clang-unwrapped}/bin/clang
  '';

  pytestFlagsArray = [
    "test/null"
    "test/backend"
  ];

  disabledTests = [
    "test_index_mnist"
    "test_index_mnist_opt"
    "test_index_mnist_opt_split"
    "test_index_mnist_split"
    "test_model_load"
    "test_mnist_val"
    "test_dataset_is_realized"
    "test_llama_basic"
    "test_llama_control_char"
    "test_llama_bytes"
    "test_llama_special1"
    "test_llama_special2"
    "test_llama_repeat"
    "test_llama_pat"
    "test_llama_early_tokenize"
    "test_autogen.py"
  ];
}
