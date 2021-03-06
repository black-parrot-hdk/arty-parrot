TOP ?= $(shell git rev-parse --show-toplevel)

export BP_SDK_DIR ?= $(TOP)/sdk
export BP_RTL_DIR ?= $(TOP)/rtl

JOBS ?= 8
PROJECT_DIR ?= $(TOP)/proj/arty-parrot

.PHONY: prep prep_lite prep_bsg bleach_all checkout checkout_sdk checkout_rtl
.PHONY: gen_proj gen_bit clean_proj

checkout_sdk:
	cd $(TOP); git submodule update --init --recursive --checkout $(BP_SDK_DIR)

checkout_rtl:
	cd $(TOP); git submodule update --init --recursive --checkout $(BP_RTL_DIR)

checkout:
	$(MAKE) checkout_rtl
	$(MAKE) checkout_sdk

prep_lite: checkout
	$(MAKE) -C $(BP_RTL_DIR) tools_lite
	$(MAKE) -C $(BP_SDK_DIR) sdk_lite

prep: prep_lite
	$(MAKE) -C $(BP_RTL_DIR) tools
	$(MAKE) -C $(BP_SDK_DIR) prog

prep_bsg: prep
	$(MAKE) -C $(BP_RTL_DIR) tools_bsg

gen_proj:
	cd proj && vivado -mode batch -source generate_project.tcl -tclargs --blackparrot_dir $(BP_RTL_DIR) --arty_dir $(TOP)

gen_bit: | $(PROJECT_DIR)
	cd proj && vivado -mode batch -source generate_bitstream.tcl -tclargs --jobs $(JOBS)

clean_proj:
	cd proj && rm -rf $(PROJECT_DIR) && rm -f *.jou *.log

$(PROJECT_DIR):
	$(error $(PROJECT_DIR) required to generate bitstream)

# USAGE: make gen_nbf_from_elf ELF=path/to/file.riscv
gen_nbf_from_elf:
	$(MAKE) -C ./nbf/ gen_nbf_from_sdk ELF=$(ELF)

# USAGE: make gen_nbf_from_sdk SUITE=bp-tests PROG=hello_world
gen_nbf_from_sdk:
	$(MAKE) -C ./nbf/ gen_nbf_from_sdk SUITE=$(SUITE) PROG=$(PROG)

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(TOP); git clean -fdx; git submodule deinit -f .
