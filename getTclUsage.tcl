#!/usr/bin/env tcl
# Traverses all Netconfigs and Xlates and returns all tcl procs that are in use. 
# 03/24/2017 - Jones - Created
# 04/07/2017 - Jones - Updated to search through NetConfigs for references on TPS Inbound/Outbound Data/Reply and Routes.
#						Added in ability to export to an HTML file with the HTML arg.


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
set header "<h2>Cloverleaf TCL Usage $environment</h2>"
lappend header "<h3>Updated $timeNow</h3>"

set content "<table id=\"table\" data-toggle=\"table\" data-sort-name=\"port\" data-classes=\"table table-striped table-hover\" data-pagination=\"true\" data-search=\"true\" data-toolbar=\"#toolbar\">"
lappend content "<thead><tr><th data-field=\"site\" data-sortable=\"true\">Site</th><th data-field=\"proc\" data-sortable=\"true\">Proc</th><th data-field=\"location\" data-sortable=\"true\">Locations</th></thead><tbody>"


if { $debug } { puts "[clock format [clock scan now] -format {%D %T}] - Site list: $sites" }
	
# Loop Over the Sites - 
foreach site $sites {
	
	puts "[clock format [clock scan now] -format {%D %T}] - Starting run for $site"	
	if {![file isdirectory $site]} {
	 	  continue 
	}
	
	set tclindexPath "$site/tclprocs/tclIndex"; set sitePath $site
	set site [file tail $site]
	
	# Setup the site in the output file.
	# lappend content "<h2>$site</h2><br><br><table><thead><tr><th>TCL Proc</th><th>References</th></thead><tbody>" 
	
	# Open the tclindex and begin to parse
	set indexHandle [open $tclindexPath]
	set text [read $indexHandle]; close $indexHandle
	set lines [split $text \n]
	# # Load the site's Netconfig in order to search for the proc in the Netconfig
	eval [exec $HciRoot/sbin/hcisetenv -root tcl $HciRoot $site]
	netcfgLoad $HciRoot/$site/NetConfig
	set connList [lsort [netcfgGetConnList]]
	
	# Go through the tclindex
	foreach line $lines {
		if { [string match "*set auto_index*" $line] } {
			set searchPlace [lindex [split $line " "] 1]
			# Get just the proc name
			set procName [string range $searchPlace [expr [string first ( $searchPlace] + 1] [expr [string first ) $searchPlace] -1]]
			set status 0; set xstatus 0
			# Now, Search for the procName in all NetConfigs
			# puts "grep -Ril $procName $sitePath/NetConfig"
			catch {exec grep -Rilw $procName $sitePath/NetConfig} results options
			# Now, search all of the Xlates
			# puts "grep -Ril --include=\"*.xlt\" $procName $sitePath/Xlate/"
			catch {exec grep -Rilw --include=*.xlt $procName $sitePath/Xlate/} xresults xoptions
			
			set status [lindex $options 1]
			set xstatus [lindex $xoptions 1]

			lappend content "<tr><td>$site</td><td>$procName</td>" 
			lappend content "<td><ul>"
			
			if { !$status } {
				foreach result [split $results \n] {
					lappend content "<li>$result</li>"
					
					# The proc is in the NetConfig. Figure out where.
					lappend content "<table>\n<tr><thead><th>Thread</th><th>UPOC</th><th>Trx Id</th><th>Destination</th></thead>"
					foreach conn $connList {
						# puts "conn: $conn"
						set data [netcfgGetConnData $conn];
						
						# Search the Inbound and Outbound Tabs for the proc.
						keylset listProcs IN_DATA "Inbound Data"; keylset listProcs OUT_DATA "Outbound Data";
						keylset listProcs IN_REPLY "Inbound Reply"; keylset listProcs OUT_REPLY "Outbound Reply";
						# set listProcs {IN_DATA OUT_DATA IN_REPLY OUT_REPLY}
						foreach type [keylkeys listProcs] {
							# Need the three keys (Procs, Args and Enabled)
							if {![catch {keylget data SMS.$type.PROCS}] } { 
								foreach p [keylget data SMS.$type.PROCS] {
										# If Found, print where the proc is.
										if {[string match $procName $p] } { 
											lappend content "<tr><td>$conn</td><td>[keylget listProcs $type]</td>"
											# puts "     -          $conn - [keylget listProcs $type]"
										}
								}
								
							}
						}
						
						# Need to check the routes as well. The procs could be sitting on the 
						# pre or post proc stack of the routes.
						# Raw routing contains a "PROCS" key that can be used.
						if {![catch {keylget data DATAXLATE}] } {
							# puts "dataxlate: [keylget data DATAXLATE]"
							foreach route [keylget data DATAXLATE] {
								# The routes break out by routedetails...
								if {![catch {keylget route ROUTE_DETAILS }]} { 
									# The route details breakdown by endpoint.
									foreach detail [keylget route ROUTE_DETAILS] {
										# The route details contain tcl Procs in the PREPROCS and POSTPROCS keys
										if {![catch {keylget detail PREPROCS.PROCS}] } { 
											foreach p [keylget detail PREPROCS.PROCS] {
												# If Found, print where the proc is.
												if {[string match $p $procName] } { 
													lappend content "<tr><td>$conn</td><td>Pre Xlate</td><td>[keylget route TRXID]</td><td>[keylget detail DEST]</td>"
													# puts "     -          $conn - [keylget route TRXID] [keylget detail DEST] - Pre Xlate" 
												}
											}
										}
										# The route details contain tcl Procs in the PREPROCS and POSTPROCS keys
										if {![catch {keylget detail POSTPROCS.PROCS}] } { 
											foreach p [keylget detail POSTPROCS.PROCS] {
												# If Found, print where the proc is.
												if {[string match $p $procName] } { 
													lappend content "<tr><td>$conn</td><td>Post Xlate</td><td>[keylget route TRXID]</td><td>[keylget detail DEST]</td>"
													# puts "     -          $conn - [keylget route TRXID] [keylget detail DEST] - POST Xlate" 
												}
											}
										}
										# The route is a raw route.
										if {![catch {keylget detail PROCS.PROCS}] } { 
											foreach p [keylget detail PROCS.PROCS] {
												# If Found, print where the proc is.
												if {[string match $p $procName] } { 
													lappend content "<tr><td>$conn</td><td>Raw Route</td><td>[keylget route TRXID]</td><td>[keylget detail DEST]</td>"
													# puts "     -          $conn - [keylget route TRXID] [keylget detail DEST] - Raw Route" 
												}
											}
										}
									}
								}	
							}
							
						}
					}
					
					lappend content "</table>"
						
				}
					
			}
				
			if { !$xstatus } {
				foreach xresult [split $xresults \n] {
					lappend content "<li>[lindex [split $xresult /] 6]</li>" 
					# puts "     -     $xresult"
				}
			}
			
			if { $status && $xstatus } {
				lappend content "<li><b>No Result</b></li>" 
				# puts "     -     No results."
			}
			
			lappend content "</ul></td></tr>"
			# puts "\n"
		}
	}
	
}
lappend content "</tbody><table>"

# Copy the existing clDocsBase.html file to a new file
set baseFile "/hci/cis6.2/integrator/contrib/html/clDocsBase.html"; set outputFile "/hci/cis6.2/integrator/contrib/html/tclUsage.html"
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
