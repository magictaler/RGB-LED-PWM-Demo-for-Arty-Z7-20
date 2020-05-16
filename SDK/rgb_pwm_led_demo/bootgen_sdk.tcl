#*****************************************************************************************
# This script will generate the boot images for existing builds. If version_string is not set,
# the version will be set to 000
# 
set demo_project_name "rgb_pwm_led_demo"

if {![info exists version_string]} {
    set version_string "0_0_0_0"
}

if {![info exists build_config]} {
    set build_config "all"
}

if { $argc == 0 } {
    set build_number 0
} else {
    set build_number [lindex $argv 0]
}

if { $argc >= 2 } {
    set index 1
    while {$index < $argc} {
        if {[string equal [lindex $argv $index] "--config"]} {
            incr index
            set build_config [string tolower [lindex $argv $index]]
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

if {![info exists version_string]} {
    set version_string "0_0_0_0"
}

if {![info exists build_config]} {
    set build_config "all"
}

puts "Generating boot images with version $version_string , build config $build_config"

if { $build_config == "release" || $build_config == "all" } {
    exec bootgen -image bootimage/${demo_project_name}.bif -arch zynq -o bootimage/${demo_project_name}_${version_string}.bin -w on -p xc7z020 
}

if { $build_config == "debug" || $build_config == "all" } {
    exec bootgen -image bootimage/${demo_project_name}_debug.bif -arch zynq -o bootimage/${demo_project_name}_${version_string}_debug.bin -w on -p xc7z020  -log info
}

