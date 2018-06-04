#!/usr/bin/env tcl
# Traverses all Netconfigs and returns all tcl procs that are in use. 
# 03/20/2017 - Jones - Created


global HciRoot; set debug 0

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sites /hci/cis6.1/integrator/rad_test }
set sites /hci/cis6.1/integrator/rad_test

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
		set data [netcfgGetConnData $conn]; set inData ""; set outData ""; set inReply ""; set outReply "";
		if {$conn == "EMR_IOR_RAD" } { 
			#  || $conn == "NOTI_OOR_DICT" || $conn == "RAD_OR_SC"
			# puts "data: $data"
			# Iterate through the list of keys.
			foreach key [keylkeys data] {
				# This level can be embedded as well...
				puts "$key: [keylget data $key]"; # puts [llength ]
				
			}
			# Get the Inbound, Outbound and Reply stacks
			# keylget data SMS.IN_DATA inData; keylget data SMS.OUT_DATA outData; keylget data SMS.IN_REPLY inReply; keylget data SMS.OUT_REPLY outReply
			
			# Strip the procs, args and whether or not the proc is enabled from the keys.
			# keylget inData PROCS idProc; keylget inData PROCSCONTROL idEnabled; keylget inData ARGS idArgs
			# puts "keylkeys: [keylkeys data]"
			# puts "Conn: $conn"
			# puts "----- Inbound Data TPS: $idProc"
			# puts "----- Inbound Data Enabled: $idEnabled"
		}
		
	}
	
}
		