#*****************************************************************************************
# This script will delete all automatically generated files that were created by the
# following scripts:
# create_project_file.tcl
# create_sdk_files.tcl
#*****************************************************************************************

# Set the reference directory for source file relative paths (by default the value is script directory path)
set origin_dir "[file normalize "."]"

# Set the demo SDK directory
set sdk_directory "[file normalize "$origin_dir/../SDK"]"

# Set the work directory to where the project file can be found
set work_directory "[file normalize "$origin_dir/work"]"

# Set the ipshared directory to where the project file can be found
set ipshared_directory "[file normalize "$origin_dir/ipshared"]"

#
# Deletes files given files or do nothing if list is empty
# file_list: List of files to delete
#
proc file_delete_if_exists {file_list} {
    if {[string length $file_list] > 0} {
        eval file delete $file_list
    }
}

puts -nonewline "THIS WILL REMOVE ALL GENERATED FILES ARE YOU SURE YOU WANT TO DO THIS (Y/N): "
flush stdout
set response [gets stdin]

if {[string toupper $response] == "Y"} {
    file_delete_if_exists [glob -nocomplain *.backup.jou]
    file_delete_if_exists [glob -nocomplain *.backup.log]
    file_delete_if_exists [glob -nocomplain *.jou]
    file_delete_if_exists [glob -nocomplain *.log]
    file delete -force $work_directory
    file delete -force $ipshared_directory
}