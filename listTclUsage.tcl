#!/usr/bin/env tcl
# Traverses all Netconfigs and Xlates and returns all tcl procs that are in use. 
# 03/24/2017 - Jones - Created
# 04/07/2017 - Jones - Updated to search through NetConfigs for references on TPS Inbound/Outbound Data/Reply and Routes.
#						Added in ability to export to an HTML file with the HTML arg.


global HciRoot; set debug 0

set outputType 0
if { [lindex $argv 0] == "HTML"} {
	# Set output for HTML
	set outputType 1
	
	# Remove the previous Html file
	if { [file exists $HciRoot/contrib/tclProcUsage.html] } {
		exec rm $HciRoot/contrib/tclProcUsage.html
	}
}

# If the outputType is HTML, setup the document output.

if { $outputType } { 
	# Put together the html Styles in order for the output to have a prettier format.
	set tableStyle "\ntable \{ \n\tfont-family: Trebuchet MS, Arial, Helvetica, sans-serif;\n\tborder-collapse: collapse;\n\twidth: 75%;\n\}\n"
	set trStyle "tr:nth-child(even)\{background-color: #f2f2f2;\}\n\n tr:hover \{background-color: #ddd;\}\n"
	set tdStyle "td, th \{ \n\t border: 1px solid #ddd;\n\t padding: 8px;\n\}\n"
	set thStyle "th \{ \n\t padding-top: 12px; \n\t padding-bottom: 12px; \n\t text-align: left; \n\t background-color: #4CAF50; \n\t color: white;\n\}\n"
	set header "<html><head><title>Cloverleaf TCL Proc Listing</title><style>$tableStyle$tdStyle$trStyle$thStyle</style></head><body>" 
	
	set output {}
}

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sites /hci/cis6.1/integrator/rad_test }
# set sites /hci/cis6.1/integrator/rad_test

if { $debug } { puts "[clock format [clock scan now] -format {%D %T}] - Site list: $sites" }

if { $outputType } { 
	lappend output "<h1>Tcl Proc Usage as of [clock format [clock scan now] -format {%D %T}]</h1><br><br><hr>"
}
puts "Tcl Proc Usage as of [clock format [clock scan now] -format {%D %T}]"
	
# Loop Over the Sites - 
foreach site $sites {
	
	puts "[clock format [clock scan now] -format {%D %T}] - Starting run for $site"	
	if {![file isdirectory $site]} {
	 	  continue 
	}
	
	set tclindexPath "$site/tclprocs/tclIndex"; set sitePath $site
	set site [file tail $site]
	
	# Setup the site in the output file.
	if { $outputType } { lappend output "<h2>$site</h2><br><br><table><thead><tr><th>TCL Proc</th><th>References</th></thead><tbody>" }
	
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

			if { $outputType } { lappend output "<tr><td>$procName</td>" }
			puts "$procName references: "
			if { $outputType } { lappend output "<td><ul>" } 
			if { !$status } {
				foreach result [split $results \n] {
					if { $outputType } { lappend output "<li>$result</li>" } 
					puts "     -     $result"
					# The proc is in the NetConfig. Figure out where.
					if { $outputType } { lappend output "<table>\n<tr><thead><th>Thread</th><th>UPOC</th><th>Trx Id</th><th>Destination</th></thead>"}
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
											if { $outputType } { lappend output "<tr><td>$conn</td><td>[keylget listProcs $type]</td>" }
											puts "     -          $conn - [keylget listProcs $type]"
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
													if { $outputType } { lappend output "<tr><td>$conn</td><td>Pre Xlate</td><td>[keylget route TRXID]</td><td>[keylget detail DEST]</td>" }
													puts "     -          $conn - [keylget route TRXID] [keylget detail DEST] - Pre Xlate" 
												}
											}
										}
										# The route details contain tcl Procs in the PREPROCS and POSTPROCS keys
										if {![catch {keylget detail POSTPROCS.PROCS}] } { 
											foreach p [keylget detail POSTPROCS.PROCS] {
												# If Found, print where the proc is.
												if {[string match $p $procName] } { 
													if { $outputType } { lappend output "<tr><td>$conn</td><td>Post Xlate</td><td>[keylget route TRXID]</td><td>[keylget detail DEST]</td>" }
													puts "     -          $conn - [keylget route TRXID] [keylget detail DEST] - POST Xlate" 
												}
											}
										}
										# The route is a raw route.
										if {![catch {keylget detail PROCS.PROCS}] } { 
											foreach p [keylget detail PROCS.PROCS] {
												# If Found, print where the proc is.
												if {[string match $p $procName] } { 
													if { $outputType } { lappend output "<tr><td>$conn</td><td>Raw Route</td><td>[keylget route TRXID]</td><td>[keylget detail DEST]</td>" }
													puts "     -          $conn - [keylget route TRXID] [keylget detail DEST] - Raw Route" 
												}
											}
										}
									}
								}	
							}
							
						}
					}
					
					if { $outputType } { lappend output "</table>" }
						
				}
					
			}
				
			if { !$xstatus } {
				foreach xresult [split $xresults \n] {
					if { $outputType } { lappend output "<li>[lindex [split $xresult /] 6]</li>" } 
					puts "     -     $xresult"
				}
			}
			
			if { $status && $xstatus } {
				if { $outputType } { lappend output "<li><b>No Result</b></li>" } 
				puts "     -     No results."
			}
			
			if { $outputType } { lappend output "</ul></td></tr>" }
			puts "\n"
		}
	}
	
	if { $outputType } { lappend output "</table><hr>" }
}
# Finish the html document and write it to a file.
if { $outputType } { 
	set htmlFile [open $HciRoot/contrib/tclProcUsage.html a]
	lappend output "</body></html>"; join ouptut; set output [ string map {\{ "" \} ""} $output ]
	set output [concat $header $output]
	# puts "output: $output"
	puts $htmlFile "$output"
	close $htmlFile
}

