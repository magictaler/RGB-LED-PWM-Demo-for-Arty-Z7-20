#*****************************************************************************************
# This script will synthesise, place & route and generate the bitfile for the
# ./work/rgb_pwm_led_demo.xpr Vivado project. The resulting files for the SDK are copied to:
# ../SDK/rgb_pwm_led_demo_top.hdf
#*****************************************************************************************

# Set maximum threads to use to number of processor on the system up to the maximum value of 8
global tcl_platform env

set max_threads $env(NUMBER_OF_PROCESSORS)

if { $max_threads > 8 } {
    set max_threads 8
}

puts "Using $max_threads cores"
set_param general.maxThreads $max_threads

# There is no simulation license and its currently not being used
set_msg_config -id "xilinx.com:ip:processing_system7:5.5-1" -new_severity "INFO"

# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "[file normalize "."]"

# Set the demo SDK directory
set sdk_directory "[file normalize "$origin_dir/../SDK/rgb_pwm_led_demo"]"

# Set the work directory to where the project file can be found
set work_directory "[file normalize "$origin_dir/work"]"
cd $work_directory

open_project rgb_pwm_led_demo.xpr

set_property STEPS.ROUTE_DESIGN.TCL.POST "$origin_dir/showstopper.tcl" [get_runs impl_1]

# Run synthesize, place & route and other tasks to get to the bitfile
# and wait for these tasks to complete
launch_runs impl_1 -to_step write_bitstream -jobs $max_threads
wait_on_run impl_1

# Copy the Vivado build result top_level_wrapper.sysdef to the SDK top level
# top_level_wrapper.hdf. It is unknown why the extension is changed in this process
# The file contains a list of files that the SDK will use to build the hardware
# package. The file can be opened with a zip file viewer.
file copy -force "[file normalize "$work_directory/rgb_pwm_led_demo.runs/impl_1/design_1_wrapper.sysdef"]" "$sdk_directory/rgb_pwm_led_demo_top.hdf"

open_run impl_1

report_utilization -file rgb_pwm_led_demo_util_report.txt

report_timing_summary -delay_type min_max -input_pins -routable_nets -name timing_1 -file rgb_pwm_led_demo_timing_report.txt

close_design
