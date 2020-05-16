#*****************************************************************************************
# This script will built the ./work/rgb_pwm_led_demo.xpr Vivado project file from the following
# sources:
#    "sources/design_1.vhd"
#    "sources/design_1_wrapper.vhd"
#    "tcl/top_level_rgb_pwm_led_demo.tcl"
#    "constraints/design_1_wrapper.xdc"
#*****************************************************************************************

# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "[file normalize "."]"

# Make and cd to the the work directory where the project should be created
set work_directory "[file normalize "$origin_dir/work"]"
file mkdir $work_directory
cd $work_directory

# Set the directory path for the original project from where this script was exported
set orig_proj_dir "[file normalize "$origin_dir"]"

# Create project
create_project rgb_pwm_led_demo -force

# Set the directory path for the new project
set proj_dir [get_property directory [current_project]]

# Parse command line arguments. Supported arguments: build, board
# Set the build number the first variable in -tclargs or 0 if none given

# defaults
set board arty-z7-20
set part "xc7z020clg400-1"
set brd_part "digilentinc.com:arty-z7-20:part0:1.0"

# Get the other named command line arguments
if { $argc >= 1 } {
    set index 1
    while {$index < $argc} {
        if {[string equal [lindex $argv $index] "board"]} {
            incr index
            if {[string equal [lindex $argv $index] "zedboard"]} {
                set part "xc7z020clg484-1"
                set board [lindex $argv $index]
            }
        }
        incr index
        puts $index
    }
}

puts "INFO: Creating project for $board board with part $part"

# Set project properties
set obj [get_projects rgb_pwm_led_demo]
set_property "default_lib" "xil_defaultlib" $obj
set_property "ip_cache_permissions" "read write" $obj
set_property "part" $part $obj
set_property "board_part" $brd_part $obj
set_property "ip_output_repo" "rgb_pwm_led_demo.cache/ip" $obj
set_property "sim.ip.auto_export_scripts" "1" $obj
set_property "simulator_language" "Mixed" $obj
set_property "target_language" "VHDL" $obj
set_property "xpm_libraries" "XPM_CDC" $obj
set_property "xsim.array_display_limit" "64" $obj
set_property "xsim.trace_limit" "65536" $obj
set_property "ip_repo_paths" "$origin_dir/ip_repo" $obj

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Call script to create block diagram for selected hardware
set origin_dir_bak $origin_dir
source $origin_dir/tcl/top_level_rgb_pwm_led_demo.tcl
set origin_dir $origin_dir_bak

# Add VHDL top architecture
add_files -norecurse $origin_dir/sources/design_1.vhd
set_property file_type {VHDL 2008} [get_files $origin_dir/sources/design_1.vhd]
add_files -norecurse $origin_dir/sources/design_1_wrapper.vhd
set_property file_type {VHDL 2008} [get_files $origin_dir/sources/design_1_wrapper.vhd]
add_files -norecurse $origin_dir/ip_repo/auto_pc_0/design_1_auto_pc_0.xci
add_files -norecurse $origin_dir/ip_repo/led_pwm_0/design_1_led_pwm_0_2.xci

upgrade_ip [get_ips] -log ip_upgrade.log
export_ip_user_files -of_objects [get_ips] -no_script -sync -force -quiet

# Set 'sources_1' fileset properties
set obj [get_filesets sources_1]
set_property "top" "design_1_wrapper" $obj

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Add constraints
add_files -fileset constrs_1 -quiet $origin_dir/constraints

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Set 'sim_1' fileset object
set obj [get_filesets sim_1]
# Empty (no sources present)

# Set 'sim_1' fileset properties
set obj [get_filesets sim_1]
set_property "top" "design_1_wrapper" $obj

# Create 'synth_1' run (if not found)
if {[string equal [get_runs -quiet synth_1] ""]} {
  create_run -name synth_1 -part $part -flow {Vivado Synthesis 2016} -strategy "Vivado Synthesis Defaults" -constrset constrs_1
} else {
  set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
  set_property flow "Vivado Synthesis 2016" [get_runs synth_1]
}
set obj [get_runs synth_1]
set_property "part" "$part" $obj

# set the current synth run
current_run -synthesis [get_runs synth_1]

# Create 'impl_1' run (if not found)
if {[string equal [get_runs -quiet impl_1] ""]} {
  create_run -name impl_1 -part $part -flow {Vivado Implementation 2016} -strategy "Vivado Implementation Defaults" -constrset constrs_1 -parent_run synth_1
} else {
  set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]
  set_property flow "Vivado Implementation 2016" [get_runs impl_1]
}
set obj [get_runs impl_1]
set_property "part" "$part" $obj
set_property "steps.write_bitstream.args.readback_file" "0" $obj
set_property "steps.write_bitstream.args.verbose" "0" $obj

# set the current impl run
current_run -implementation [get_runs impl_1]

# Set the build constant to the build number given as parameter. If not given
# then it is left to the value in the block diagram. This value must be left
# at 0.
open_bd_design [file normalize "$work_directory/rgb_pwm_led_demo.srcs/sources_1/bd/design_1/design_1.bd"]

save_bd_design

close_bd_design [get_bd_designs system]

set_property source_mgmt_mode DisplayOnly [current_project]

set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]

puts "INFO: Project created:rgb_pwm_led_demo"
