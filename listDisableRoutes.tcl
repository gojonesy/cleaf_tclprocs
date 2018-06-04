#!/usr/bin/env tcl
# Traverses all Netconfigs and returns pertinent information.
# 03/15/2017 - Jones - Created


global HciRoot; set debug 0

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sites /hci/cis6.1/integrator/adt_test }

if { $debug } { puts "[clock format [clock scan now] -format {%D %T}] - Site list: $sites" }

# Loop Over the Sites - 
foreach site $sites {
	puts "[clock format [clock scan now] -format {%D %T}] - Starting run for $site"
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
		# set protocol ""; set host ""; set port ""; set pdlType ""
		
		# puts "conn: $conn"
		# Get the connection type and data
		set data [netcfgGetConnData $conn]
		# if { $debug && $conn == "EXT_recv" } { puts "data: $data" }
		keylget data DATAXLATE dataXlate
		
		if {[llength $dataXlate] > 0} {
			foreach route $dataXlate {
				keylget route ROUTE_DETAILS route_details; keylget route TRXID trxid
				# if { $debug && $conn == "EXT_recv" } { puts "route: $route" }
				foreach routeDetail $route_details {
					set dest ""; set enabled 1
					keylget routeDetail DEST dest; catch { keylget routeDetail DETAILS_ENABLED enabled }
					
					if { !$enabled } { puts "Site: $site - $conn - $trxid - Route: $dest is a disabled route." }
				}
			}
		}
		
		
	}
}