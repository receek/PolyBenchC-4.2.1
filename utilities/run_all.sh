#!/bin/bash

### native target
./utilities/run_bench.sh target/native


### wasi target
# jit wasmer
./utilities/run_bench.sh target/wasi wasmer cranelift
./utilities/run_bench.sh target/wasi wasmer llvm

# jit wasmetime
./utilities/run_bench.sh target/wasi wasmtime cranelift

# aot wasmer
./utilities/run_bench.sh target/wasi wasmer cranelift aot
./utilities/run_bench.sh target/wasi wasmer llvm aot

# aot wasmetime
./utilities/run_bench.sh target/wasi wasmtime cranelift aot


### wasix target
# jit wasmer
./utilities/run_bench.sh target/wasix wasmer cranelift
./utilities/run_bench.sh target/wasix wasmer llvm

# aot wasmer
./utilities/run_bench.sh target/wasix wasmer cranelift aot
./utilities/run_bench.sh target/wasix wasmer llvm aot