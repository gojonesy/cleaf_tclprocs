#!/usr/bin/env tcl

global HciRoot; set debug 0

# List exclusions
set siteExcludes {clvrtest test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { puts "[clock format [clock scan now] -format {%D %T}] - Site list: $sites" }

foreach site $sites {
	if {![file isdirectory $site]} {
	 	  continue 
	}
	
	set site [file tail $site]
	if {[lsearch -exact $siteExcludes $site] != -1} {continue} ;# Skip excluded sites
	puts "[clock format [clock scan now] -format {%D %T}] - Counts for $site"
	eval [exec $HciRoot/sbin/hcisetenv -root tcl $HciRoot $site]
	# exec ksh -c "setroot; setsite $site"
	# puts [exec ksh -c "showroot"]
	set errDBCount [exec hcidbdump -e -C ]
	# set recDBCount [exec hcidbdump -r | awk "{print \$1}" | wc -l ]
	set recDBCount [exec hcidbdump -r -C]
	
	if { $errDBCount > 0 } { puts "[clock format [clock scan now] -format {%D %T}] - Error DB Count: $errDBCount" }
	if { $recDBCount > 0 } { puts "[clock format [clock scan now] -format {%D %T}] - Recovery DB Count: $recDBCount" }
	
}