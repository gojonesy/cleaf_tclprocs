#!/usr/bin/env tcl
# Locates all Tables that are in use and where they are in use.
# 04/07/2017 - Jones - Created

global HciRoot; set debug 0
set environment [lindex $argv 0]

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sitePath /hci/cis6.2/integrator/adt_test }
set timeNow [clock format [clock scan now] -format {%D %T}] 
if { $debug } { puts "$timeNow - Site list: $sites" }

set sitePath "/hci/cis6.2/integrator/*/Xlate/"

# #### The output is placed into a new HTML file in the Contrib directory. This file is built with sections to hold the header and content lists.
set header "<h2>Cloverleaf Table Usage $environment</h2>" 
lappend header "<h3>Updated $timeNow</h3>"

set content "<table id=\"table\" data-toggle=\"table\" data-classes=\"table table-striped table-hover\" data-pagination=\"true\" data-search=\"true\" data-toolbar=\"#toolbar\">" 
lappend content "<thead><tr><th data-field=\"table\" data-sortable=\"true\">Table</th><th data-field=\"location\" data-sortable=\"true\">Location</th><th data-field=\"count\" data-sortable=\"true\" data-sorter=\"numberSorter\">Count</th></thead><tbody id=\"listing\">"

# Traverse the Tables Directory and search all Xlates for the table. 
set tableDir "/hci/cis6.2/integrator/clvrtest/Tables"
catch {exec ls -l /hci/cis6.2/integrator/clvr[string tolower $environment]/Tables | awk {{print $9}} } results options

# Testing only
# set results "BRIDGE_loc.tbl Carestream_locations.tbl"

foreach table $results {

	lappend content "<tr><td>$table</td>"
	set tableName [lindex [split $table .] 0]
	catch {exec grep -Rilw --include=*.xlt $tableName {*}[glob $sitePath] } xresults xoption
	# exec grep -Rilw --include=*.xlt prairie_to_emr_trans_codes {*}[glob /hci/cis6.2/integrator/*/Xlate/]
	set status [lindex $xoption 1]
	if { !$status } {
		# puts "$tableName - \n     $xresults"
		lappend content "<td><ul>"
		foreach result $xresults {
			lappend content "<li>$result</li>"
		}
		lappend content "</td><td>[llength $xresults]</td>"
	} else {
		lappend content "<td>Not in Use</td><td>0</td>"
	}
	
}

lappend content "</table>"

# Copy the existing clDocsBase.html file to a new file
set baseFile "/hci/cis6.2/integrator/contrib/html/clDocsBase.html"; set outputFile "/hci/cis6.2/integrator/contrib/html/tableUsage.html"
set base [open $baseFile r]; set output [open $outputFile w]

# Read in the base file and copy each line to the outputFile
while {[gets $base line] != -1} {
	# puts "line: $line"
	# Need to modify the links for in subdirectories:

	if { [string match "<!--- ### Header ### -->" [string trimleft $line]]} {
		puts $output [join $header \n]
	} elseif { [string match "<!--- ### MainContent ### -->" [string trimleft $line]] } {
		puts $output [join $content \n]
	} elseif { [string match "<!--- ### CSS ### -->" [string trimleft $line]] } {
		puts $output [join $css \n]
	} elseif { [string match "<!--- ### JS ### -->" [string trimleft $line]] } {
		puts $output [join $js \n]
	} else {
		puts $output $line
	}
}


close $base; close $output







