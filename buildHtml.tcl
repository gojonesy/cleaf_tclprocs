#!/usr/bin/env tcl
# Provided a Header and Content lists and a source file and dest file, builds an HTML document based upon the source file submitted.
# 04/12/2017 - Jones - Created

# Get the args. 
# Usage is:
# buildHtml.tcl <header_list> <content_list> source_file dest_file

if {$argc < 4} {
	puts "This script requires 4 arguments"
	return "Error" "Not enough args supplied to script."
}

# puts "Args are: $argv"
# foreach arg $argv {
	# puts "Arg: $arg"
# }
# Check for valid args. the first two do not matter too much.
# The 3 arg needs to exist. If not, exit with error.

if { ![file exists [lindex $argv 2]] } { return "Error" "Source file does not exist." }

# Copy the existing clDocsBase.html file to a new file
set baseFile [lindex $argv 2]; set outputFile [lindex $argv 3]
set base [open $baseFile r]; set output [open $outputFile w]

# # Read in the base file and copy each line to the outputFile
while {[gets $base line] != -1} {
	# puts "line: $line"
	if { [string match "<!--- ### Header ### --->" [string trimleft $line]]} {
		puts $output [join [lindex $argv 0] \n]
	} elseif { [string match "<!--- ### MainContent ### --->" [string trimleft $line]] } {
		puts $output [join [lindex $argv 1] \n]
	} else {
		puts $output $line
	}
}

close $base; close $output

return "Success" "$outputFile built successfully"
