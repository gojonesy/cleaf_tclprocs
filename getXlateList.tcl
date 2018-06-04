#!/usr/bin/env tcl
# Locates all Xlates that are in use and where they are in use.
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

# #### The output is placed into a new HTML file in the Contrib directory. This file is built with sections to hold the header and content lists.
set header "<h2>Cloverleaf Xlate Usage $environment</h2>" 
lappend header "<h3>Updated $timeNow</h3>"

set content "<table id=\"table\" data-toggle=\"table\" data-classes=\"table table-striped table-hover\" data-pagination=\"true\" data-search=\"true\" data-toolbar=\"#toolbar\">" 
lappend content "<thead><tr><th data-field=\"site\" data-sortable=\"true\">Site</th><th data-field=\"thread\" data-sortable=\"true\">Thread</th><th data-field=\"xlate\" data-sortable=\"true\">Xlate</th><th data-field=\"dest\" data-sortable=\"true\">Destination</th><th data-field=\"route\" data-sortable=\"true\">Route</th></thead><tbody>"

# Traverse the Xlate Directory and search the site's NetConfig for the xlate. 
# set tableDir "/hci/cis6.2/integrator/clvrtest/Tables"
# catch {exec ls -l /hci/cis6.2/integrator/clvrtest/Tables | awk {{print $9}} } results options

# Testing only
# set results "BRIDGE_loc.tbl Carestream_locations.tbl"

foreach site $sites {

	set sitePath $site
	set site [file tail $site]
	# Get the Xlate list
	catch {exec ls -l $sitePath/Xlate | awk {{ print $9 }} } listing options
	
	# Load the Site's NetConfig
	eval [exec $HciRoot/sbin/hcisetenv -root tcl $HciRoot $site]
	netcfgLoad $HciRoot/$site/NetConfig
	set connList [lsort [netcfgGetConnList]]
	
	foreach xlate $listing {
		catch {exec grep -Rilw $xlate $sitePath/NetConfig} xresults xoptions
		# lappend content "<li>$xlate</li></td>"
		
		set status [lindex $xoptions 1]
		if { !$status } {
			# Find the location of the xlate
			foreach conn $connList {
				set data [netcfgGetConnData $conn];
				
				# The Dataxlate portion of the Netconfig contains the routes with the Xlate references
				if {![catch {keylget data DATAXLATE}] } {
					foreach route [keylget data DATAXLATE] {
						# The routes break out by routedetails...
						if {![catch {keylget route ROUTE_DETAILS }]} { 
							# The route details breakdown by endpoint.
							foreach detail [keylget route ROUTE_DETAILS] {
								if {![catch {keylget detail XLATE }]} { 
									if {[string match [keylget detail XLATE] $xlate] } { 
										lappend content "<tr>"
										lappend content "<td>$site</td>"
										lappend content "<td>$conn</td><td>[keylget detail XLATE]</td><td>[keylget detail DEST]</td>"
										lappend content "<td>[keylget route TRXID]</td>"
										# puts "[keylget detail XLATE] - [keylget detail DEST] - [keylget route TRXID]"
									}
								}
							}
						}
					}
				}
			}
		} else {
			lappend content "<tr><td>$site</td><td>N/A</td><td>$xlate</td><td>NA</td><td>Not In Use</td>"
		}
	}	
	
}

lappend content "</table>"

# Copy the existing clDocsBase.html file to a new file
set baseFile "/hci/cis6.2/integrator/contrib/html/clDocsBase.html"; set outputFile "/hci/cis6.2/integrator/contrib/html/xlateUsage.html"
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







