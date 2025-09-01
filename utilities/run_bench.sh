#!/bin/bash

set -eu

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
"medley/floyd-warshall" \
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
    counter=0
    limit=$2
    while [ $counter -lt $limit ]; do
        echo -n "$counter "
        eval "$cmd"
        counter=$((counter+1))
    done

    echo
}

get_cmd() {
    local bin_file="$1"

    if [ "$RUNTIME" == "wasmer" ]; then
        if [ "$AOT" ]; then
            result_file="$bin_file.wasmer.$BACKEND.aot.result"
            cmd="wasmer --quiet run --disable-cache $bin_file.wasmer.$BACKEND.aot >> $result_file"
        else
            result_file="$bin_file.wasmer.$BACKEND.jit.result"
            cmd="wasmer --quiet run --disable-cache --$BACKEND $bin_file >> $result_file"
        fi
    elif [ "$RUNTIME" == "wasmtime" ]; then
        if [ "$AOT" ]; then
            result_file="$bin_file.wasmtime.$BACKEND.aot.result"
            cmd="wasmtime run --allow-precompiled  $bin_file.wasmtime.$BACKEND.aot >> $result_file"
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

        case "$variant" in
            "mini"|"small"|"medium")
                iters="100"
                ;;
            "large")
                iters="20"
                ;;
            "extralarge")
                iters="5"
                ;;
            *)
                echo "Wrong variant: $variant"
                exit 1
                ;;
        esac

        if [ "$RUNTIME" ]; then
            # wasip1 and wasix runs with jit and aot approaches
            bin_file="${benchmark_name}_$variant.$target"
            get_cmd "$bin_file"
            rm -f "$bench_dir/$result_file"

            echo "Testing $target $RUNTIME $BACKEND: $bin_file..."

            (
                cd $bench_dir;
                run "$cmd" "$iters";
            )

        else
            # native run
            result_file="${benchmark_name}_$variant.native.result"
            rm -f "$bench_dir/$result_file"

            echo "Testing native: ${benchmark_name}_$variant..."
            (
                cd $bench_dir;
                run "./${benchmark_name}_$variant >> $result_file" "$iters";
            )

        fi
    done

done