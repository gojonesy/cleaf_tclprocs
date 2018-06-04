#!/usr/bin/env tcl
# Traverses all Netconfigs and returns all in use Ports. Output should be redirected to an HTML file.
# 03/20/2017 - Jones - Created


global HciRoot; set debug 0
set environment [lindex $argv 0]

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sites /hci/cis6.2/integrator/adt_test }
set timeNow [clock format [clock scan now] -format {%D %T}] 
if { $debug } { puts "$timeNow - Site list: $sites" }

# #### The output is placed into a new HTML file in the Contrib directory. This file is built with sections to hold the header and content lists.
set header "<h2>Cloverleaf Port Listing $environment</h3>"
lappend header "<h3>Updated $timeNow</h3>"

set content "<table id=\"table\" data-toggle=\"table\" data-sort-name=\"port\" data-classes=\"table table-striped table-hover\" data-pagination=\"true\" data-search=\"true\" data-toolbar=\"#toolbar\">"
lappend content "<thead><tr><th data-field=\"site\" data-sortable=\"true\">Site</th><th data-field=\"thread\" data-sortable=\"true\">Thread</th><th data-field=\"port\" data-sortable=\"true\">Port</th><th data-field=\"host\" data-sortable=\"true\" data-sorter=\"numberSorter\">Host</th></thead><tbody>"

# Setup the columns JSON output.
set columns "\[\{\"name\":\"site\",\"title\":\"Site\",\"breakpoints\":\"sm\"\},"
lappend columns "\{\"name\":\"thread\",\"title\":\"Thread\"\},"
lappend columns "\{\"name\":\"port\",\"title\":\"Port\"\},"
lappend columns "\{\"name\":\"host\",\"title\":\"Host\"\}\n\]"

# puts [join $columns \n]
set rows "\["

# Loop Over the Sites - 
foreach site $sites {
	# Sets up the heading for the site and then table with the table headings.
	
	if {![file isdirectory $site]} {
	 	  continue 
	}
	
	set site [file tail $site]
	
	# Load the site's Netconfig
	eval [exec $HciRoot/sbin/hcisetenv -root tcl $HciRoot $site]
	netcfgLoad $HciRoot/$site/NetConfig
	
	# Get the Process list
	set processList [lsort [netcfgGetProcList]]
	# if {$debug} { puts "[clock format [clock scan now] -format {%D %T}] - ProcList: $processList" }
	
	# Get the Connection list
	set connList [lsort [netcfgGetConnList]]
	# if {$debug} { puts "[clock format [clock scan now] -format {%D %T}] - ConnList: $connList" }
	
	foreach conn $connList {
		set protocol ""; set host ""; set port ""; set isServer 0
		# puts "conn: $conn"
		# Get the connection type and data
		set data [netcfgGetConnData $conn]
		# if {$conn == "EMR_IOR_RAD"} { puts "data: $data"}
		# if { $debug && $conn == "EXT_recv" } { puts "data: $data" }
		keylget data PROTOCOL.TYPE protocol; keylget data PROTOCOL.HOST host
		keylget data PROTOCOL.PORT port; keylget data PROTOCOL.PDLTYPE pdlType; keylget data PROTOCOL.ISSERVER isServer
		
		if { $port == "" } {
			# No port information. We skip the connection
			continue
		} else {
			# This starts a new table row
			lappend content "<tr>"
			lappend content "<td>$site</td><td>$conn</td><td>$port</td><td>$host</td>"
			lappend rows "\{\"site\":\"$site\",\"thread\":\"$conn\",\"port\":\"$port\",\"host\":\"$host\"\},"
		}
	}

} 
# Finish the html document.
lappend content "</tbody><table>"
lappend rows "\]"
# Needed to remove the final comma
set lastRow [expr [llength $rows] - 2]
set rows [lreplace $rows $lastRow $lastRow [string trimright [lindex $rows $lastRow] ","]]
set jsonColumnsFile "/hci/cis6.2/integrator/contrib/html/portsColumns.json"
set jsonRowsFile "/hci/cis6.2/integrator/contrib/html/portsRows.json"

puts [open $jsonColumnsFile w] [join $columns \n]
puts [open $jsonRowsFile w] [join $rows \n]
# Copy the existing clDocsBase.html file to a new file
set baseFile "/hci/cis6.2/integrator/contrib/html/clDocsBase.html"; set outputFile "/hci/cis6.2/integrator/contrib/html/portsListing.html"
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

	