#!/usr/bin/env tcl
# Traverses all Netconfigs and returns all in use Ports.
# 03/20/2017 - Jones - Created


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
		set protocol ""; set host ""; set port ""; set pdlType ""; set isServer 0
		
		# puts "conn: $conn"
		# Get the connection type and data
		set data [netcfgGetConnData $conn]
		# if {$conn == "EMR_IOR_RAD"} { puts "data: $data"}
		# if { $debug && $conn == "EXT_recv" } { puts "data: $data" }
		keylget data PROTOCOL.TYPE protocol; keylget data PROTOCOL.HOST host
		keylget data PROTOCOL.PORT port; keylget data PROTOCOL.PDLTYPE pdlType; keylget data PROTOCOL.ISSERVER isServer
		
		if {$port != ""} {
			if {$isServer} {
				puts "Conn: $conn - Server Thread - $port"
			} else {
			puts "Conn: $conn - $host - $port"
			}
		}
			
		
			
	}
		
		
}

	