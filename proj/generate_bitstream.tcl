set script_jobs 8
set script_file "generate_bitstream.tcl"

# Help information for this script
proc print_help {} {
  variable script_file
  puts "\nDescription:"
  puts "Generate bitstream for project.\n"
  puts "Syntax:"
  puts "$script_file"
  puts "$script_file -tclargs \[--jobs <N>\]"
  puts "$script_file -tclargs \[--help\]\n"
  puts "Usage:"
  puts "Name                   Description"
  puts "-------------------------------------------------------------------------"
  puts "\[--help\]               Print help information for this script"
  puts "\[--jobs <N>\]           Number of jobs for synthesis and implementation"
  puts "-------------------------------------------------------------------------\n"
  exit 0
}

if { $::argc > 0 } {
  for {set i 0} {$i < $::argc} {incr i} {
    set option [string trim [lindex $::argv $i]]
    switch -regexp -- $option {
      "--jobs"   { incr i; set script_jobs [lindex $::argv $i] }
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

# open project
open_project arty-parrot/arty-parrot.xpr

# run implementation
reset_run synth_1
launch_runs synth_1 -jobs $script_jobs
wait_on_run synth_1

reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs $script_jobs
wait_on_run impl_1
