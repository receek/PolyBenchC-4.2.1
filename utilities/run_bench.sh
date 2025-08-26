#!/bin/bash

set -eux

TEST_DIR=$1
EXECUTOR=${2:-""}
RESULT_SUFFIX=${3:-""}
# =${4:-""}

if [ $EXECUTOR ] && [ ! $RESULT_SUFFIX ]; then
    echo "help: $0 <test_dir> [ <runtime> <result file suffix> ]"
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
arch="$(basename $TEST_DIR)"


run() {
    cmd=$1
    for i in {0..5}; do
        eval "$cmd"
    done 
}

for bench in "${benchmarks[@]}"; do

    bench_dir="$TEST_DIR/$bench"
    benchmark_name="$(basename $bench_dir)"

    for variant in "${datasets[@]}"; do

        if [ "$EXECUTOR" ]; then
            # wasip1 and wasix runs with jit and aot approaches
            result_file="${benchmark_name}_$variant.$arch-$RESULT_SUFFIX"
            rm -f "$bench_dir/$result_file"

            (
                cd $bench_dir;
                run "$EXECUTOR ${benchmark_name}_$variant.$arch >> $result_file"
            )

        else
            # native run
            result_file="${benchmark_name}_$variant.native.result"
            rm -f "$bench_dir/$result_file"

            (
                cd $bench_dir;
                run "./${benchmark_name}_$variant >> $result_file"
            )

        fi
    done

done