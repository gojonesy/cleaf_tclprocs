#!/usr/bin/env tcl

global HciRoot; set debug 1

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { puts "[clock format [clock scan now] -format {%D %T}] - Site list: $sites" }


# Begin site loops:
foreach site $sites {
	
	puts "[clock format [clock scan now] -format {%D %T}] - Starting run for $site"
	if {![file isdirectory $site]} {
	 	  continue 
	}
	
	# Load the site's Netconfig
	eval [exec $HciRoot/sbin/hcisetenv -root tcl $HciRoot $site]
	netcfgLoad $HciRoot/$site/NetConfig
	
	# Get the Process list
	set processList [lsort [netcfgGetProcList]]
	if {$debug} { puts "[clock format [clock scan now] -format {%D %T}] - ProcList: $processList" }
	
	# Perform the Action in the args on the process.
	foreach process $processList {
		puts [exec hcienginerun -p $process]
		
	}
}
	 
