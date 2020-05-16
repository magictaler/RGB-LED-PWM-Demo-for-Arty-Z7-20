#
# Inserts a linked source reference into a project .project file.
# project_dir: Path to project to open
# name: Link name
# location: Path to reference
# type: Link type (1 for file, 2 for folder)
#
proc add_linked_resource {project_dir name location type} {
  set link "<link><name>$name</name><type>$type</type><location>$location</location></link>"
  set filename "$project_dir/.project"

  # Read lines of file (name in “filename” variable) into variable “lines”
  set f [open $filename "r"]
  set lines [split [read $f] "\n"]
  close $f

  # Find linked resources group
  set idx [lsearch -regexp [lreverse $lines] "^</linkedResources>"]
  if {$idx < 0} {

      # Add one if it doesn't exist
      set idx [lsearch -regexp [lreverse $lines] "^</projectDescription>"]
      if {$idx < 0} {
        error "did not find insertion point for linkedResources group in $filename"
      }
      incr idx

      set linkedresourcesgroup "<linkedResources>\n</linkedResources>"
      set lines [linsert $lines end-$idx {*}$linkedresourcesgroup]
  }

  # Place the insertion point above linkedResources end
  incr idx

  # Insert the resource lines
  set lines [linsert $lines end-$idx {*}$link]

  # Write the lines back to the file
  set f [open $filename "w"]
  puts $f [join $lines "\n"]
  close $f
}

#
# Inserts a linked source reference into a project's .cproject file.
# project_dir: Path to project to open
# name: Link name
# location: Path to reference
#
proc add_source_entries {project_dir name location} {
  set sourceentries "<sourceEntries><entry excluding=\"$name\" flags=\"VALUE_WORKSPACE_PATH|RESOLVED\" kind=\"sourcePath\" name=\"\"/><entry flags=\"VALUE_WORKSPACE_PATH|RESOLVED\" kind=\"sourcePath\" name=\"$name\"/></sourceEntries>"
  set filename "$project_dir/.cproject"

  # Read lines of file (name in “filename” variable) into variable “lines”
  set f [open $filename "r"]
  set lines [split [read $f] "\n"]
  close $f

  # Find the insertion index in the reversed list
  set idx [lsearch -regexp [lreverse $lines] "</folderInfo>"]
  if {$idx < 0} {
      error "did not find insertion point in $filename"
  }

  # Insert the resource lines
  set lines [linsert $lines end-$idx {*}$sourceentries]

  incr idx

  # Find the insertion index in the reversed list
  set idx [lsearch -start $idx -regexp [lreverse $lines] "</folderInfo>"]
  if {$idx < 0} {
      error "did not find insertion point in $filename"
  }

  # Insert the resource lines
  set lines [linsert $lines end-$idx {*}$sourceentries]

  # Write the lines back to the file
  set f [open $filename "w"]
  puts $f [join $lines "\n"]
  close $f
}

#
# Gets the processor definition (instance) from the hardware package
# hw_project_name: Name of the hardware package to use
#
proc get_processor_name {hw_project_name} {
  set periphs [getperipherals $hw_project_name]
  # For each line of the peripherals table
  foreach line [split $periphs "\n"] {
    set values [regexp -all -inline {\S+} $line]
    # If the last column is "PROCESSOR", then get the "IP INSTANCE" name (1st col)
    if {[lindex $values end] == "PROCESSOR"} {
      return [lindex $values 0]
    }
  }
  return ""
}

#
# Gets the processor definition (instance) from the hardware package
# hw_project_name: Name of the hardware package to use
#
proc get_second_processor_name {hw_project_name} {
  set periphs [getperipherals $hw_project_name]
  set first_found 0
  # For each line of the peripherals table
  foreach line [split $periphs "\n"] {
    set values [regexp -all -inline {\S+} $line]
    # If the last column is "PROCESSOR", then get the "IP INSTANCE" name (1st col)
    if {[lindex $values end] == "PROCESSOR"} {
      if {$first_found == 1} {
        return [lindex $values 0]
      }
      set first_found 1
    }
  }
  return ""
}
