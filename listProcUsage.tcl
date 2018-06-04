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
	
	# Open the tclindex and begin to parse
	set tclindexPath "$site/tclprocs/tclindex"
	
	set indexHandle [open $tclindexPath]
	set text [read $indexHandle]; close $indexHandle
	set lines [split $text \n]

	foreach line $lines {
		puts "Line: $line"
	}
	
	
}