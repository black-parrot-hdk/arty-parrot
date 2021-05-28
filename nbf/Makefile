TOP ?= $(shell git rev-parse --show-toplevel)

export BP_SDK_DIR ?= $(TOP)/sdk
export BP_RTL_DIR ?= $(TOP)/rtl

include $(BP_SDK_DIR)/Makefile.common

BP_COMMON_DIR ?= $(BP_RTL_DIR)/bp_common

RISCV_OBJDUMP ?= $(CROSS_COMPILE)objdump -d -t
RISCV_OBJCOPY ?= $(CROSS_COMPILE)objcopy
MEM2NBF       ?= $(BP_COMMON_DIR)/software/py/nbf.py

SED           ?= sed

# only unicore configurations are currently supported
NCPUS       := 1
PADDR_WIDTH := 33
NBF_FLAGS ?= --ncpus=$(NCPUS) --config --addr_width=$(PADDR_WIDTH)

# individual target args
ARG_ELF_NAME     := $(ELF)
ARG_ELF_BASENAME := $(notdir $(ARG_ELF_NAME))
ARG_OUT_BASENAME := ./$(ARG_ELF_BASENAME)

UNFREEZE_COMMAND := 03_000200002_0000000000000000

.PHONY: gen_nbf_from_elf gen_nbf_from_sdk

# USAGE: make gen_nbf_from_elf ELF=path/to/file.riscv
gen_nbf_from_elf:
	$(RISCV_OBJCOPY) -O verilog $(ARG_ELF_NAME) $(ARG_OUT_BASENAME).mem
	$(SED) -i "s/@8/@0/g" $(ARG_OUT_BASENAME).mem
	python $(MEM2NBF) $(NBF_FLAGS) --mem=$(ARG_OUT_BASENAME).mem > $(ARG_OUT_BASENAME).nbf

	# The final fence and "finish" are unnecessary for arty-parrot, but their replies become
	# intermingled with true program output. We remove them for convenience.
	sed -i -e '/$(UNFREEZE_COMMAND)/,$$d' $(ARG_OUT_BASENAME).nbf
	echo "$(UNFREEZE_COMMAND)" >> $(ARG_OUT_BASENAME).nbf

make_output_dirs:
	mkdir -p $(dir $(ARG_OUT_BASENAME))

# USAGE: make gen_nbf_from_sdk SUITE=bp-tests PROG=hello_world
gen_nbf_from_sdk: ARG_ELF_NAME     := $(BP_SDK_PROG_DIR)/$(SUITE)/$(PROG).riscv
gen_nbf_from_sdk: ARG_OUT_BASENAME := ./$(SUITE)/$(PROG).riscv
gen_nbf_from_sdk: make_output_dirs gen_nbf_from_elf
