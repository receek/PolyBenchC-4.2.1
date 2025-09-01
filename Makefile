
.PHONY: all
all: native

DATASET_SIZES = MINI SMALL MEDIUM LARGE EXTRALARGE
LOWER_DATASET_SIZES := $(foreach size,$(DATASET_SIZES),$(shell echo $(size) | tr '[:upper:]' '[:lower:]'))

BENCHMARKS := $(foreach f,$(shell cat ./utilities/benchmark_list), \
	$(shell realpath --relative-to=. $(f)) \
)

SUBDIRS := $(foreach f,$(BENCHMARKS),$(shell dirname $(f)))
KERNELS := $(foreach f,$(SUBDIRS),$(shell basename $(f)))

NATIVE_BENCHMARKS := $(foreach f,$(BENCHMARKS), \
	$(shell echo $(f).native) \
)
NATIVE_EXECS := $(foreach dir,$(SUBDIRS), \
	$(foreach size,$(LOWER_DATASET_SIZES), \
		$(shell echo $(dir)/$(shell basename $(dir))_$(size)) \
	) \
)
NATIVE_TARGET_PREFIX = target/native
NATIVE_TARGETDIRS := $(foreach dir,$(SUBDIRS),$(shell echo $(NATIVE_TARGET_PREFIX)/$(dir)))
NATIVE_TARGETFILES := $(foreach file,$(NATIVE_EXECS),$(shell echo $(NATIVE_TARGET_PREFIX)/$(file)))

WASI_BENCHMARKS := $(foreach f,$(BENCHMARKS), \
	$(shell echo $(f).wasi) \
)
WASI_EXECS := $(foreach file,$(NATIVE_EXECS),$(shell echo $(file).wasi))
WASI_TARGET_PREFIX = target/wasi
WASI_TARGETDIRS := $(foreach dir,$(SUBDIRS),$(shell echo $(WASI_TARGET_PREFIX)/$(dir)))
WASI_TARGETFILES := $(foreach file,$(WASI_EXECS),$(shell echo $(WASI_TARGET_PREFIX)/$(file)))
WASI_CC := "${WASI_SDK_PATH}/bin/clang --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot"

WASI_WASMER_AOT_CRANELIFT_TARGETFILES := $(foreach file,$(WASI_EXECS),$(shell echo $(WASI_TARGET_PREFIX)/$(file).wasmer.cranelift.aot))
WASI_WASMER_AOT_SINGLEPASS_TARGETFILES := $(foreach file,$(WASI_EXECS),$(shell echo $(WASI_TARGET_PREFIX)/$(file).wasmer.singlepass.aot))
WASI_WASMER_AOT_LLVM_TARGETFILES := $(foreach file,$(WASI_EXECS),$(shell echo $(WASI_TARGET_PREFIX)/$(file).wasmer.llvm.aot))

WASI_WASMTIME_AOT_CRANELIFT_TARGETFILES := $(foreach file,$(WASI_EXECS),$(shell echo $(WASI_TARGET_PREFIX)/$(file).wasmtime.cranelift.aot))

WASIX_BENCHMARKS := $(foreach f,$(BENCHMARKS), \
	$(shell echo $(f).wasix) \
)

WASIX_EXECS := $(foreach file,$(NATIVE_EXECS),$(shell echo $(file).wasix))
WASIX_TARGET_PREFIX = target/wasix
WASIX_TARGETDIRS := $(foreach dir,$(SUBDIRS),$(shell echo $(WASIX_TARGET_PREFIX)/$(dir)))
WASIX_TARGETFILES := $(foreach file,$(WASIX_EXECS),$(shell echo $(WASIX_TARGET_PREFIX)/$(file)))
WASIX_CFLAGS = --target=wasm32-wasmer-wasi \
         -O2 \
         --sysroot $(WASIX_SYSROOT)/sysroot \
         -matomics \
         -mbulk-memory \
         -mmutable-globals \
         -pthread \
         -mthread-model posix \
         -ftls-model=local-exec \
         -fno-trapping-math \
         -D_WASI_EMULATED_MMAN \
         -D_WASI_EMULATED_SIGNAL \
		 -D_WASI_EMULATED_PROCESS_CLOCKS \
         -Wall \
         -Wno-null-pointer-arithmetic \
         -Wno-unused-parameter \
         -Wno-sign-compare \
         -Wno-unused-variable \
         -Wno-unused-function \
         -Wno-ignored-attributes \
         -Wno-missing-braces \
         -Wno-ignored-pragmas \
         -Wno-unused-but-set-variable \
         -Wno-unknown-warning-option \
         -Wno-parentheses \
         -Wno-shift-op-parentheses \
         -Wno-bitwise-op-parentheses \
         -Wno-logical-op-parentheses \
         -Wno-string-plus-int \
         -Wno-dangling-else \
         -Wno-unknown-pragmas \
         -MP

WASIX_CLFLAGS = -Wl,--shared-memory \
          -Wl,--max-memory=4294967296 \
          -Wl,--import-memory \
          -Wl,--export-dynamic \
		  -Wl,--export=__heap_base \
          -Wl,--export=__stack_pointer \
          -Wl,--export=__data_end \
          -Wl,--export=__wasm_init_tls \
          -Wl,--export=__wasm_signal \
          -Wl,--export=__tls_size \
          -Wl,--export=__tls_align \
          -Wl,--export=__tls_base

WASIX_CC := "${WASI_SDK_PATH}/bin/clang $(WASIX_CFLAGS) $(WASIX_CLFLAGS)"

WASIX_WASMER_AOT_CRANELIFT_TARGETFILES := $(foreach file,$(WASIX_EXECS),$(shell echo $(WASIX_TARGET_PREFIX)/$(file).wasmer.cranelift.aot))
WASIX_WASMER_AOT_SINGLEPASS_TARGETFILES := $(foreach file,$(WASIX_EXECS),$(shell echo $(WASIX_TARGET_PREFIX)/$(file).wasmer.singlepass.aot))
WASIX_WASMER_AOT_LLVM_TARGETFILES := $(foreach file,$(WASIX_EXECS),$(shell echo $(WASIX_TARGET_PREFIX)/$(file).wasmer.llvm.aot))

### build native
.PHONY: $(NATIVE_BENCHMARKS)
$(NATIVE_BENCHMARKS):
	for size in $(DATASET_SIZES); do \
		$(MAKE) -C $(shell dirname $@) DATASET_SIZE="$$size"; \
	done

$(NATIVE_TARGETDIRS):
	mkdir -p $@

$(NATIVE_EXECS): $(NATIVE_BENCHMARKS) $(NATIVE_TARGETDIRS)
	cp $@ target/native/$@

$(NATIVE_TARGETFILES): $(NATIVE_EXECS)

.PHONY: native
native: $(NATIVE_TARGETFILES)

### build wasi
.PHONY: WASI_SDK
WASI_SDK: 
ifndef WASI_SDK_PATH
	$(error SDK variable is not defined. Please set it for the 'build' target.)
endif

.PHONY: $(WASI_BENCHMARKS)
$(WASI_BENCHMARKS): WASI_SDK
	for size in $(DATASET_SIZES); do \
		$(MAKE) -C $(shell dirname $@) \
			CC=$(WASI_CC) \
			DATASET_SIZE="$$size" \
			CUSTOM_FLAGS="-D_WASI_EMULATED_PROCESS_CLOCKS -lwasi-emulated-process-clocks" \
			EXT=".wasi" ; \
	done

$(WASI_TARGETDIRS):
	mkdir -p $@

$(WASI_EXECS): $(WASI_BENCHMARKS) $(WASI_TARGETDIRS)
	cp $@ target/wasi/$@

$(WASI_TARGETFILES): $(WASI_EXECS)

wasi: $(WASI_EXECS)

$(WASI_WASMER_AOT_CRANELIFT_TARGETFILES): $(WASI_TARGETFILES)
	wasmer compile --target $(shell llvm-config --host-target) --cranelift $(@:%.wasmer.cranelift.aot=%) -o $@

wasi-wasmer-cranelift: $(WASI_WASMER_AOT_CRANELIFT_TARGETFILES)

# $(WASI_WASMER_AOT_SINGLEPASS_TARGETFILES): $(WASI_TARGETFILES)
# 	wasmer compile --singlepass $(@:%.wasmer.singlepass.aot=%) -o $@

# wasi-wasmer-singlepass: $(WASI_WASMER_AOT_SINGLEPASS_TARGETFILES)

$(WASI_WASMER_AOT_LLVM_TARGETFILES): $(WASI_TARGETFILES)
	wasmer compile --target $(shell llvm-config --host-target) --llvm $(@:%.wasmer.llvm.aot=%) -o $@

wasi-wasmer-llvm: $(WASI_WASMER_AOT_LLVM_TARGETFILES)

$(WASI_WASMTIME_AOT_CRANELIFT_TARGETFILES): $(WASI_TARGETFILES)
	wasmtime compile --target $(shell llvm-config --host-target) $(@:%.wasmtime.cranelift.aot=%) -o $@

wasi-wasmtime-cranelift: $(WASI_WASMTIME_AOT_CRANELIFT_TARGETFILES)

### build wasix
.PHONY: WASIX_SDK 
WASIX_SDK:
ifndef WASI_SDK_PATH
	$(error SDK variable is not defined. Please set it for the 'build' target.)
endif
ifndef WASIX_SYSROOT
	$(error WASIX_SYSROOT variable is not defined. Please set it for the 'build' target.)
endif

.PHONY: $(WASIX_BENCHMARKS)
$(WASIX_BENCHMARKS): WASIX_SDK
	for size in $(DATASET_SIZES); do \
		$(MAKE) -C $(shell dirname $@) \
			CC=$(WASIX_CC) \
			DATASET_SIZE="$$size" \
			CUSTOM_FLAGS="-D_WASI_EMULATED_PROCESS_CLOCKS -lwasi-emulated-process-clocks" \
			EXT=".wasix" ; \
	done

$(WASIX_TARGETDIRS):
	mkdir -p $@

$(WASIX_EXECS): $(WASIX_BENCHMARKS) $(WASIX_TARGETDIRS)
	cp $@ target/wasix/$@

$(WASIX_TARGETFILES): $(WASIX_EXECS)

wasix: $(WASIX_TARGETFILES)

$(WASIX_WASMER_AOT_CRANELIFT_TARGETFILES): $(WASIX_TARGETFILES)
	wasmer compile --target $(shell llvm-config --host-target) --cranelift $(@:%.wasmer.cranelift.aot=%) -o $@

wasix-wasmer-cranelift: $(WASIX_WASMER_AOT_CRANELIFT_TARGETFILES)

# $(WASIX_WASMER_AOT_SINGLEPASS_TARGETFILES): $(WASIX_TARGETFILES)
# 	wasmer compile --singlepass $(@:%.wasmer.singlepass.aot=%) -o $@

# wasix-wasmer-singlepass: $(WASIX_WASMER_AOT_SINGLEPASS_TARGETFILES)

$(WASIX_WASMER_AOT_LLVM_TARGETFILES): $(WASIX_TARGETFILES)
	wasmer compile --target $(shell llvm-config --host-target) --llvm $(@:%.wasmer.llvm.aot=%) -o $@

wasix-wasmer-llvm: $(WASIX_WASMER_AOT_LLVM_TARGETFILES)

.PHONY: all
all: native wasi wasix wasi-wasmer-cranelift wasi-wasmer-llvm wasi-wasmtime-cranelift wasix-wasmer-cranelift wasix-wasmer-llvm

### cleaning
.PHONY: clean
clean:
	@for dir in $(SUBDIRS); do \
		$(MAKE) --silent -C $$dir clean; \
	done
	@for file in $(NATIVE_TARGETFILES); do \
		rm -f $$file; \
	done
	@for file in $(WASI_TARGETFILES); do \
		rm -f $$file; \
	done
	@for file in $(WASIX_TARGETFILES); do \
		rm -f $$file; \
	done