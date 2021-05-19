TOP ?= $(shell git rev-parse --show-toplevel)

export BP_SDK_DIR := $(TOP)/sdk
export BP_RTL_DIR := $(TOP)/rtl

.PHONY: prep prep_bsg bleach_all

checkout:
	cd $(TOP); git submodule update --init --recursive --checkout $(BP_RTL_DIR)
	cd $(TOP); git submodule update --init --recursive --checkout $(BP_SDK_DIR)

prep_lite: checkout
	$(MAKE) -C $(BP_RTL_DIR) tools_lite
	$(MAKE) -C $(BP_SDK_DIR) sdk_lite

prep: prep_lite
	$(MAKE) -C $(BP_RTL_DIR) tools
	$(MAKE) -C $(BP_SDK_DIR) prog

prep_bsg: prep
	$(MAKE) -C $(BP_RTL_DIR) tools_bsg

.PHONY: gen_proj
gen_proj:
	cd proj && vivado -mode batch -source fpga_host_test.tcl -tclargs --blackparrot_dir $(BP_RTL_DIR) --arty_dir ./

.PHONY: clean_proj
clean_proj:
	cd proj && rm -r fpga_bp

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(TOP); git clean -fdx; git submodule deinit -f .
