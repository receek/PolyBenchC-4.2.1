#!/bin/bash

set -eux

TEST_DIR=$1
RUNTIME=${2:-""}
BACKEND=${3:-""}
AOT=${4:-""}

if [ ! $TEST_DIR ]; then
    echo "help: $0 <test_dir> [ <runtime> <result file suffix> [<aot flag>]]"
    exit 1
fi

if [ $RUNTIME ] && [ ! $BACKEND ]; then
    echo "help: $0 <test_dir> [ <runtime> <result file suffix> [<aot flag>]]"
    exit 1
fi

benchmarks=( \
"datamining/correlation" \
"datamining/covariance" \
"linear-algebra/kernels/2mm" \
"linear-algebra/kernels/3mm" \
"linear-algebra/kernels/atax" \
"linear-algebra/kernels/bicg" \
"linear-algebra/kernels/doitgen" \
"linear-algebra/kernels/mvt" \
"linear-algebra/blas/gemm" \
"linear-algebra/blas/gemver" \
"linear-algebra/blas/gesummv" \
"linear-algebra/blas/symm" \
"linear-algebra/blas/syr2k" \
"linear-algebra/blas/syrk" \
"linear-algebra/blas/trmm" \
"linear-algebra/solvers/cholesky" \
"linear-algebra/solvers/durbin" \
"linear-algebra/solvers/gramschmidt" \
"linear-algebra/solvers/lu" \
"linear-algebra/solvers/ludcmp" \
"linear-algebra/solvers/trisolv" \
"medley/deriche" \
"medley/floyd-warshall/floyd" \
"medley/nussinov" \
"stencils/adi" \
"stencils/fdtd-2d" \
"stencils/heat-3d" \
"stencils/jacobi-1d" \
"stencils/jacobi-2d" \
"stencils/seidel-2d" \
)

datasets=("mini" "small" "medium" "large" "extralarge")
target="$(basename $TEST_DIR)"

if [ "$RUNTIME" == "wasmtime" ] && [ "$target" == "wasix" ]; then
    echo "wasmtime doesn't support wasix"
    exit 1
fi

run() {
    cmd=$1
    for i in {0..5}; do
        eval "$cmd"
    done 
}

get_cmd() {
    local bin_file="$1"

    if [ "$RUNTIME" == "wasmer" ]; then
        if [ "$AOT" ]; then
            result_file="$bin_file.wasmer.$BACKEND.aot.result"
            cmd="wasmer run $bin_file.wasmer.$BACKEND.aot >> $result_file"
        else
            result_file="$bin_file.wasmer.$BACKEND.jit.result"
            cmd="wasmer run --$BACKEND $bin_file >> $result_file"
        fi
    elif [ "$RUNTIME" == "wasmtime" ]; then
        if [ "$AOT" ]; then
            result_file="$bin_file.wasmtime.$BACKEND.aot.result"
            cmd="wasmtime run $bin_file.wasmtime.$BACKEND.aot >> $result_file"
        else
            result_file="$bin_file.wasmtime.$BACKEND.jit.result"
            cmd="wasmtime run $bin_file >> $result_file"
        fi
    else
        echo "Specify runtime: wasmer or wasmtime"
        exit 1
    fi

    return 0
}

for bench in "${benchmarks[@]}"; do

    bench_dir="$TEST_DIR/$bench"
    benchmark_name="$(basename $bench_dir)"

    for variant in "${datasets[@]}"; do

        if [ "$RUNTIME" ]; then
            # wasip1 and wasix runs with jit and aot approaches
            bin_file="${benchmark_name}_$variant.$target"
            get_cmd "$bin_file"
            rm -f "$bench_dir/$result_file"

            (
                cd $bench_dir;
                run "$cmd";
            )

        else
            # native run
            result_file="${benchmark_name}_$variant.native.result"
            rm -f "$bench_dir/$result_file"

            (
                cd $bench_dir;
                run "./${benchmark_name}_$variant >> $result_file";
            )

        fi
    done

    exit 0

done