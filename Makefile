
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
	$(shell echo $(f).wasm) \
)
WASI_EXECS := $(foreach file,$(NATIVE_EXECS),$(shell echo $(file).wasm))
WASI_TARGET_PREFIX = target/wasi
WASI_TARGETDIRS := $(foreach dir,$(SUBDIRS),$(shell echo $(WASI_TARGET_PREFIX)/$(dir)))
WASI_TARGETFILES := $(foreach file,$(WASI_EXECS),$(shell echo $(WASI_TARGET_PREFIX)/$(file)))
WASI_CC := "${WASI_SDK_PATH}/bin/clang --sysroot=${WASI_SDK_PATH}/share/wasi-sysroot"


### build native
.PHONY: $(NATIVE_BENCHMARKS)
$(NATIVE_BENCHMARKS):
	for size in $(DATASET_SIZES); do \
		$(MAKE) -C $(shell dirname $@) DATASET_SIZE="$$size"; \
	done

$(NATIVE_TARGETDIRS):
	mkdir -p $@

$(NATIVE_EXECS): $(NATIVE_BENCHMARKS) $(NATIVE_TARGETDIRS)
	mv $@ target/native/$@

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
			EXT=".wasm" ; \
	done

$(WASI_TARGETDIRS):
	mkdir -p $@

$(WASI_EXECS): $(WASI_BENCHMARKS) $(WASI_TARGETDIRS)
	mv $@ target/wasi/$@

$(WASI_TARGETFILES): $(WASI_EXECS)

.PHONY: wasi
wasi: $(WASI_TARGETFILES)

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