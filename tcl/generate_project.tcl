# Script to automatically generate BlackParrot on Arty A7-100T

## Set basic project info with sane defaults
set arty_dir ".."
set project_name "arty-parrot-TEST"

set script_file "generate_project.tcl"

## Parse Arguments to script
# Help information for this script
proc print_help {} {
  variable script_file
  puts "\nDescription:"
  puts "Recreate a Vivado project from this script. The created project will be"
  puts "functionally equivalent to the original project for which this script was"
  puts "generated. The script contains commands for creating a project, filesets,"
  puts "runs, adding/importing sources and setting properties on various objects.\n"
  puts "Syntax:"
  puts "$script_file"
  puts "$script_file -tclargs \[--blackparrot_dir <path>\]"
  puts "$script_file -tclargs \[--arty_dir <path>\]"
  puts "$script_file -tclargs \[--project_name <name>\]"
  puts "$script_file -tclargs \[--project_dir <path>\]"
  puts "$script_file -tclargs \[--help\]\n"
  puts "Usage:"
  puts "Name                   Description"
  puts "-------------------------------------------------------------------------"
  puts "\[--project_name <name>\] Create project with the specified name. Default"
  puts "                       name is the name of the project from where this"
  puts "                       script was generated.\n"
  puts "\[--help\]               Print help information for this script"
  puts "-------------------------------------------------------------------------\n"
  exit 0
}

if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--arty_dir"   { incr i; set arty_dir [lindex $::argv $i] }
      "--project_name" { incr i; set project_name [lindex $::argv $i] }
      "--help"         { print_help }
      default {
        if { [regexp {^-} $option] } {
          puts "ERROR: Unknown option '$option' specified, please type '$script_file -tclargs --help' for usage info.\n"
          return 1
        }
      }
    }
  }
}

# variables that depend on args
set blackparrot_dir "$arty_dir/rtl"
set board_repo_path "$arty_dir/common/board_files"
set project_dir "$arty_dir/proj"
set tcl_dir "$arty_dir/tcl"
set arty_src_dir "$arty_dir/src"

## Setup the basic project info

# Create project
create_project ${project_name} ${project_dir}/${project_name} -part xc7a100tcsg324-1

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Set project properties
set proj_obj [current_project]
set_property -name "board_part_repo_paths" -value [file normalize $board_repo_path] -objects $proj_obj
set_property -name "board_part" -value "digilentinc.com:arty-a7-100:part0:1.0" -objects $proj_obj
set_property -name "default_lib" -value "xil_defaultlib" -objects $proj_obj
set_property -name "enable_vhdl_2008" -value "1" -objects $proj_obj
set_property -name "ip_cache_permissions" -value "read write" -objects $proj_obj
set_property -name "ip_output_repo" -value "$proj_dir/${project_name}.cache/ip" -objects $proj_obj
set_property -name "mem.enable_memory_map_generation" -value "1" -objects $proj_obj
set_property -name "platform.board_id" -value "arty-a7-100" -objects $proj_obj
set_property -name "sim.central_dir" -value "$proj_dir/${project_name}.ip_user_files" -objects $proj_obj
set_property -name "sim.ip.auto_export_scripts" -value "1" -objects $proj_obj
set_property -name "simulator_language" -value "Mixed" -objects $proj_obj
# Loading the "source hierarchy" requires a huge amount of RAM and time.
# "None" disables this. "DisplayOnly" is the default.
set_property -name "source_mgmt_mode" -value "None" -objects $proj_obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

## Create the memory_design block diagram, wrapper, and add to wrapper to project
set memory_design_tcl "${tcl_dir}/memory_design.tcl"
puts "Reading block design: ${memory_design_tcl}\n"
source $memory_design_tcl

## Automatically discover BlackParrot source files

# reads the top-level flist and returns a 2-element list: [list $include_dirs $source_files]
proc load_bp_sources_from_flist { blackparrot_dir } {
  # Set include vars used in flists
  set BP_TOP_DIR "$blackparrot_dir/bp_top/"
  set BP_COMMON_DIR "$blackparrot_dir/bp_common/"
  set BP_BE_DIR "$blackparrot_dir/bp_be/"
  set BP_FE_DIR "$blackparrot_dir/bp_fe/"
  set BP_ME_DIR "$blackparrot_dir/bp_me/"
  set BASEJUMP_STL_DIR "$blackparrot_dir/external/basejump_stl/"
  set HARDFLOAT_DIR "$blackparrot_dir/external/HardFloat/"

  set flist_path "$blackparrot_dir/bp_top/syn/flist.vcs"

  set f [split [string trim [read [open $flist_path r]]] "\n"]
  set source_files [list ]
  set include_dirs [list ]
  foreach x $f {
    if {![string match "" $x] && ![string match "#" [string index $x 0]]} {
      # If the item starts with +incdir+, directory files need to be added
      if {[string match "+" [string index $x 0]]} {
        set trimchars "+incdir+"
        set temp [string trimleft $x $trimchars]
        set expanded [subst $temp]
        lappend include_dirs $expanded
      } elseif {[string match "*bsg_mem_1rw_sync_mask_write_bit.v" $x]} {
        # bitmasked memories are incorrectly inferred in Kintex 7 and Ultrascale+ FPGAs, this version maps into lutram correctly
        set replace_hard "$BASEJUMP_STL_DIR/hard/ultrascale_plus/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v"
        set expanded [subst $replace_hard]
        set normalized [file normalize $expanded]
        lappend source_files $normalized
      } elseif {[string match "*bsg_mem_1rw_sync_mask_write_bit_synth.v" $x]} {
        # omit this file, it's unused now that we've replaced the bsg_mem_1rw_sync_mask_write_bit module above
      } else {
        set expanded [subst $x]
        set normalized [file normalize $expanded]
        lappend source_files $normalized
      }
    }
  }

  list $include_dirs $source_files
}

lassign [load_bp_sources_from_flist $blackparrot_dir] flist_include_dirs flist_source_files

# TODO: replace below with external flist file
set additional_include_dirs [list \
  [file normalize "${arty_src_dir}/include/" ] \
]
set additional_source_files [list \
  [file normalize "${arty_src_dir}/include/bp_fpga_host_pkg.sv" ] \
  [file normalize "${arty_src_dir}/v/uart_rx.sv" ] \
  [file normalize "${arty_src_dir}/v/uart_tx.sv" ] \
  [file normalize "${arty_src_dir}/v/bp_fpga_host.sv" ] \
  [file normalize "${arty_src_dir}/v/bp_fpga_host_io_in.sv" ] \
  [file normalize "${arty_src_dir}/v/bp_fpga_host_io_out.sv" ] \
  [file normalize "${arty_src_dir}/v/arty_parrot.sv" ] \
  [file normalize "${blackparrot_dir}/external/basejump_stl/bsg_cache/bsg_cache_to_axi.v" ] \
  [file normalize "${blackparrot_dir}/external/basejump_stl/bsg_cache/bsg_cache_to_axi_rx.v" ] \
  [file normalize "${blackparrot_dir}/external/basejump_stl/bsg_cache/bsg_cache_to_axi_tx.v" ] \
]

set all_include_dirs [concat $flist_include_dirs $additional_include_dirs]
set_property include_dirs $all_include_dirs [current_fileset]

# Set 'sources_1' fileset object
set obj [get_filesets sources_1]
add_files -norecurse -scan_for_includes -fileset $obj $flist_source_files
add_files -norecurse -scan_for_includes -fileset $obj $additional_source_files

# Set 'sources_1' fileset file properties for remote files
foreach source_file [concat $flist_source_files $additional_source_files] {
  set file_obj [get_files -of_objects [get_filesets sources_1] [list "*$source_file"]]
  set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
}

# Set 'sources_1' fileset file properties for local files
# None

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property -name "top" -value "arty_parrot" -objects $obj
set_property -name "top_auto_set" -value "0" -objects $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Set 'constrs_1' fileset object
set obj [get_filesets constrs_1]

# Add/Import constrs file and set constrs file properties
set file "[file normalize ${arty_src_dir}/xdc/constraints.xdc]"
set file_added [add_files -norecurse -fileset $obj [list $file]]
set file "${arty_src_dir}/xdc/constraints.xdc"
set file [file normalize $file]
set file_obj [get_files -of_objects [get_filesets constrs_1] [list "*$file"]]
set_property -name "file_type" -value "XDC" -objects $file_obj

# Set 'constrs_1' fileset properties
set obj [get_filesets constrs_1]

## TODO: simulation stuff
## Create 'sim_1' fileset (if not found)
#if {[string equal [get_filesets -quiet sim_1] ""]} {
#  create_fileset -simset sim_1
#}
#
## Set 'sim_1' fileset object
#set obj [get_filesets sim_1]
#set sim_include_dirs [list \
#  [file normalize "${arty_src_dir}/external"] \
#]
#set sim_source_files [list \
#  [file normalize "${blackparrot_dir}/external/basejump_stl/bsg_cache/bsg_cache_pkg.v" ] \
#  [file normalize "${arty_src_dir}/test/mig_ddr3_ram_testbench.sv"] \
#  [file normalize "${arty_src_dir}/test/arty_parrot_testbench.sv"] \
#  [file normalize "${blackparrot_dir}/external/basejump_stl/bsg_test/bsg_nonsynth_reset_gen.v"] \
#  [file normalize "${blackparrot_dir}/external/basejump_stl/bsg_test/bsg_nonsynth_clock_gen.v"] \
#]
#set ddr3_model_path [file normalize "${arty_src_dir}/external/ddr3_model.sv"]
#if {[file exists $ddr3_model_path]} {
#  lappend sim_source_files $ddr3_model_path
#} else {
#  puts "WARNING: DDR3 model files not found at \"${arty_src_dir}/external\", some testbenches will not work"
#}
#
#set_property include_dirs [concat $sim_include_dirs $all_include_dirs] $obj
#add_files -norecurse -scan_for_includes -fileset $obj $sim_source_files
#
#
## Set 'sim_1' fileset file properties for remote files
#foreach source_file $sim_source_files {
#  set file_obj [get_files -of_objects [get_filesets sim_1] [list "*$source_file"]]
#  set_property -name "file_type" -value "SystemVerilog" -objects $file_obj
#  set_property -name "used_in" -value "simulation" -objects $file_obj
#  set_property -name "used_in_implementation" -value "0" -objects $file_obj
#  set_property -name "used_in_synthesis" -value "0" -objects $file_obj
#}
#
## Set 'sim_1' fileset file properties for local files
## None
#
## Set 'sim_1' fileset properties
#set obj [get_filesets sim_1]
#set_property -name "hbs.configure_design_for_hier_access" -value "1" -objects $obj
#set_property -name "top" -value "arty_parrot_testbench" -objects $obj
#set_property -name "top_auto_set" -value "0" -objects $obj
#set_property -name "top_lib" -value "xil_defaultlib" -objects $obj

