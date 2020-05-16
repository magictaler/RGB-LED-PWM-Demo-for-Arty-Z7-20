#*****************************************************************************************
# This script will built the Vivado SDK project from the following
# sources:
#    "rgb_pwm_led_demo.hdf"
#    "rgb_pwm_led_demo/src"
#    "bootimage/rgb_pwm_led_demo.bif"
#    "bootimage/rgb_pwm_led_demo_debug.bif"
#*****************************************************************************************

# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "[file normalize "."]"

set demo_project_name "rgb_pwm_led_demo"
set hw_project_name "demo_hw_platform"
set bsp_project_cpu0_name "demo_freertos_cpu0_bsp"
set fsbl_project_name "fsbl"
set fsbl_bsp_project_name "fsbl_bsp"

source "../common/shared_procs.tcl"

# Set the build number the first variable passed on the command line or 0 if none given
if { $argc == 0 } {
    set build_number 0
} else {
    set build_number [lindex $argv 0]
}

set build_config "all"

# Get the other named command line arguments, first is --config all/debug/release
if { $argc >= 2 } {
    set index 1
    while {$index < $argc} {
        if {[string equal [lindex $argv $index] "--config"]} {
            incr index
            set build_config [string tolower [lindex $argv $index]]
        }
        if {[string equal [lindex $argv $index] "--clean"]} {
            puts "Clean project directories selected. Running clean script"
            set force_clean true
            source clean_all.tcl
        }
        incr index
    }
    puts "Build config selected: $build_config"
}

# If no valid build config is selected, default to all.
if { $build_config != "all" && $build_config != "release" && $build_config != "debug"} {
    puts "Invalid build config selected, defaulting to all"
    set build_config "all"
}

puts "RGB LED PWM Demo hardware project $demo_project_name"

# Check HDF exists
set hdf_file_name ${demo_project_name}_top.hdf
if { ![file exists ${hdf_file_name}] } {
    puts "File $hdf_file_name is missing, exiting."
    exit 1
}

# Set the workspace to the current directory. From now on the results of all other
# commands will end up here.
setws .

# Take the FPGA Build's top_level_wrapper.hdf and create a hardware package
createhw -name $hw_project_name -hwspec $hdf_file_name

# Create main BSP
# Use the hardware package and create a board support package (BSP) for FreeRTOS
# Configure the main BSP to contain the correct libraries and parameters
createbsp -name $bsp_project_cpu0_name -hwproject $hw_project_name -proc [get_processor_name $hw_project_name] -os freertos901_xilinx

# Configure freertos kernel
configbsp -bsp $bsp_project_cpu0_name tick_rate 1000
configbsp -bsp $bsp_project_cpu0_name total_heap_size 262144
configbsp -bsp $bsp_project_cpu0_name minimal_stack_size 512

# Enable floating point context in tasks.  This is necessary for avoiding corruption of floating point
# registers (used by floating point operations and some GCC library functions) when context switching.
configbsp -bsp $bsp_project_cpu0_name -append extra_compiler_flags "-DconfigUSE_TASK_FPU_SUPPORT=2 -DLWIP_SO_RCVTIMEO=1"


# Wait for 4 seconds to allow xilinx to free up resources to avoid future builds failing.
puts "Waiting for xilinx to release control of header files"
after 4000

regenbsp -bsp $bsp_project_cpu0_name

# Create FSBL BSP
# Use the hardware package and create a board support package (BSP)
# Configure the main BSP to contain the correct libraries and parameters
createbsp -name $fsbl_bsp_project_name -hwproject $hw_project_name -proc [get_processor_name $hw_project_name] -os standalone
setlib -bsp $fsbl_bsp_project_name -lib xilffs

# Add and configure Xilinx In-serial Flash (xilisf) library
setlib -bsp $fsbl_bsp_project_name -lib xilisf
configbsp -bsp $fsbl_bsp_project_name serial_flash_family 5
configbsp -bsp $fsbl_bsp_project_name serial_flash_interface 3

# Wait for 2 seconds to allow xilinx to free up resources to avoid future builds failing.
puts "Waiting for xilinx to release control of header files"
after 4000

regenbsp -bsp $fsbl_bsp_project_name

# Create first stage bootloader
createapp -name $fsbl_project_name -app {Empty Application} -bsp $fsbl_bsp_project_name -hwproject ${hw_project_name} -proc [get_processor_name $hw_project_name] -os standalone
file delete "$origin_dir/$fsbl_project_name/src/lscript.ld"
add_linked_resource "$origin_dir/$fsbl_project_name" "src/ps7_init.c" "WORKSPACE_LOC/$hw_project_name/ps7_init.c" 1

# Create an empty application in the demo directory where we already keep our sources.
# This way our sources are added to the empty project
createapp -name $demo_project_name -app {Empty Application} -bsp $bsp_project_cpu0_name -hwproject ${hw_project_name} -proc [get_processor_name $hw_project_name] -os freertos901_xilinx
file delete "$demo_project_name/src/lscript.ld"

# Get the version info from the version.c and print it
set file [open "$demo_project_name/src/version.c"]
while {[gets $file line] != -1} {
    if {[regexp {VERSION_([A-Z]+).*([0-9]+)} $line matched version_part value]} {
        dict set version [string tolower $version_part] $value
    }
}
close $file
set version_string [dict get $version major]_[dict get $version minor]_[dict get $version bugfix]_$build_number
puts "Building version: [string map {_ .} $version_string]"

# Use our own linker files instead of autogenerated
file copy -force "lscripts/$demo_project_name/lscript.ld" "$demo_project_name/src/"
file copy -force "lscripts/$fsbl_project_name/lscript.ld" "$fsbl_project_name/src/"

after 3000

if { $build_config == "release" || $build_config == "all" } {
    # Build the release version of the Demo and the FSBL
    configapp -app $demo_project_name build-config Release
    configapp -app $fsbl_project_name build-config Release

    # Set the build number
    puts "Add macro: BUILD_NUMBER=$build_number"

    # Configure FSBL
    configapp -app $fsbl_project_name define-compiler-symbols "BUILD_NUMBER=$build_number"
    configapp -app $fsbl_project_name define-compiler-symbols "PROJECT=FSBL_APP"
    configapp -app $fsbl_project_name include-path "\"\${workspace_loc:/$hw_project_name}\""

    # Configure main project
    configapp -app $demo_project_name define-compiler-symbols "BUILD_NUMBER=$build_number"
    configapp -app $demo_project_name define-compiler-symbols "CS_PLATFORM=CS_P_ZYNQ"
    configapp -app $demo_project_name define-compiler-symbols "MG_LOCALS"
    configapp -app $demo_project_name define-compiler-symbols "CS_NDEBUG"
    configapp -app $demo_project_name define-compiler-symbols "PROJECT=RGB_PWM_LED_DEMO_APP"
    configapp -app $demo_project_name define-compiler-symbols "CPU0"
    configapp -app $demo_project_name linker-misc { -Xlinker --defsym=_STACK_SIZE=0x200000 }
    configapp -app $demo_project_name linker-misc { -Xlinker --defsym=_HEAP_SIZE=0x200000 }
    configapp -app $demo_project_name libraries "m"

    projects -build
}

if { $build_config == "debug" || $build_config == "all" } {
    # Build the debug version of the Demo and the FSBL
    # The debug version is build last, so the project remains configured for the debug
    # after it has been generated. This is easier for developers using the project files.
    configapp -app $demo_project_name build-config Debug
    configapp -app $fsbl_project_name build-config Debug

    # Set the build number
    puts "Add macro: BUILD_NUMBER=$build_number"

    # Configure FSBL
    configapp -app $fsbl_project_name define-compiler-symbols "BUILD_NUMBER=$build_number"
    configapp -app $fsbl_project_name define-compiler-symbols "FSBL_DEBUG_INFO"
    configapp -app $fsbl_project_name define-compiler-symbols "FSBL_PERF"
    configapp -app $fsbl_project_name define-compiler-symbols "PROJECT=FSBL_APP"
    configapp -app $fsbl_project_name include-path "\"\${workspace_loc:/$hw_project_name}\""

    # Configure main application
    configapp -app $demo_project_name define-compiler-symbols "BUILD_NUMBER=$build_number"
    configapp -app $demo_project_name define-compiler-symbols "CS_PLATFORM=CS_P_ZYNQ"
    configapp -app $demo_project_name define-compiler-symbols "MG_LOCALS"
    configapp -app $demo_project_name define-compiler-symbols "DEBUG"
    configapp -app $demo_project_name define-compiler-symbols "PROJECT=RGB_PWM_LED_DEMO_APP"
    configapp -app $demo_project_name define-compiler-symbols "CPU0"
    configapp -app $demo_project_name linker-misc { -Xlinker --defsym=_STACK_SIZE=0x200000 }
    configapp -app $demo_project_name linker-misc { -Xlinker --defsym=_HEAP_SIZE=0x200000 }
    configapp -app $demo_project_name libraries "m"

    projects -build
}

exit
