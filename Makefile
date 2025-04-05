
.PHONY: all
all: native

DATASET_SIZES = MINI SMALL MEDIUM LARGE EXTRALARGE
LOWER_DATASET_SIZES := $(foreach size,$(DATASET_SIZES),$(shell echo $(size) | tr '[:upper:]' '[:lower:]'))

BENCHMARKS := $(foreach f,$(shell cat ./utilities/benchmark_list), \
	$(shell realpath --relative-to=. $(f)) \
)

SUBDIRS := $(foreach f,$(BENCHMARKS),$(shell dirname $(f)))
KERNELS := $(foreach f,$(SUBDIRS),$(shell basename $(f)))

EXECS := $(foreach dir,$(SUBDIRS), \
	$(foreach size,$(LOWER_DATASET_SIZES), \
		$(shell echo $(dir)/$(shell basename $(dir))_$(size)) \
	) \
)

TARGETDIRS := $(foreach f,$(SUBDIRS),$(shell echo target/$(f)))
TARGETFILES := $(foreach f,$(EXECS),$(shell echo target/$(f)))

### build native
.PHONY: $(BENCHMARKS)
$(BENCHMARKS):
	# echo $@
	for size in $(DATASET_SIZES); do \
		$(MAKE) -C $(shell dirname $@) DATASET_SIZE="$$size"; \
	done

$(TARGETDIRS):
	mkdir -p $@

$(EXECS): $(BENCHMARKS) $(TARGETDIRS)
	mv $@ target/$@

$(TARGETFILES): $(EXECS)

.PHONY: native
native: $(TARGETFILES)

### cleaning
.PHONY: clean
clean:
	for dir in $(SUBDIRS); do \
		$(MAKE) -C $$dir clean; \
	done
	for file in $(TARGETFILES); do \
		rm $$file; \
	done