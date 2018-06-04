#!/bin/env tcl
######################################################################
# Name:		 tableExport
# Purpose:	Exports a Cloverleaf table to a csv, txt or html formatted file
#
# Args:		<Filename ( name of table file with full path)> 
#			<File type (csv, txt or html)> Defaults to csv
# Notes:	
#     	Output sent to stdout. Can pipe to file for saving.
#
# Author:       Jones
# Date:         05/26/2017

global HciRoot; set debug 0

set tableName [lindex $argv 0]
set outputType [lindex $argv 1]

if {[file exists $tableName]} {
	set tableFile [open $tableName r]
	
	set skip 0; set EOF 0
	set tableData [split [read $tableFile] \n]
	close $tableFile
	set indexes ""
	# Get the lindex numbers for the entries
	foreach entry $tableData {
		if {[string match "#*" $entry]} {
			lappend indexes $entry
		}
	}
	puts $indexes; puts "Length: [llength $indexes]"
	
	# Find the line that contains "dflt=*"
	set tableStart [lsearch $tableData "dflt=*" ]
	
	# Starting at the list index, grab pairs of lines
	for {set i $tableStart} {$i < [llength $tableData]} {incr i} {
		# The first time through, we have to increment i
		if {$i == $tableStart} {puts "Numbers equal"; incr i}
		if {[lindex $tableData $i] == "#" || [lindex $tableData $i] == ""} {continue}
		if {[string match "*encoded*" [lindex $tableData $i]]} {continue}
	
		# puts "Starts at [lindex $tableData $i]"
		lappend values [list [lindex $tableData $i] [lindex $tableData [expr $i + 1]]]
		incr i
		
	}
	
	puts "values: $values"
	
	# Build the Output.
	if { $outputType == "html"} { 
		# puts "Build some HTML"
		puts "<html>\n<head></head>\n<body>\n<table border=1>\n<tr><td><b>Input</b></td><td><b>Output</b></td></tr>"
		foreach val $values {
			puts "<tr><td>[lindex $val 0]</td><td>[lindex $val 1]</td></tr>"
		}
		puts "</table></body></html>"
	} elseif {$outputType == "csv"} { 
		# puts "Build some commas"
		puts "Input,Output"
		foreach val $values {
			puts "[lindex $val 0],[lindex $val 1]"
		}
	} else {
		# Output as text
		# Get the spacing right
		set long 0; set lengths ""
		foreach val $values {
			lappend lengths [string length [lindex $val 1]]
		}
		# set padding to the longest list item:
		set long [lindex [lsort -decreasing -integer $lengths] 0]; set space " "; set spaces [string repeat $space $long]
		puts "long: $long"
		# Build the Output
		puts "Input$spaces Output"
		foreach val $values {
			# puts "[lindex $val 0]$spaces[lindex $val 1]"
			puts [lindex $val 0]$spaces[lindex $val 1]
		}
	}
	
	
	# puts "outList: $outList"
}
