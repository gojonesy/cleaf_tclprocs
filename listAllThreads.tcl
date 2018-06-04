#!/usr/bin/env tcl

global HciRoot; set debug 1

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

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
	
	# loop over the Connection List
	foreach conn $connList {
		set protocol ""; set host ""; set port ""; set pdlType ""
		
		# puts "conn: $conn"
		# Get the connection type and data
		set data [netcfgGetConnData $conn]
		# puts "data: $data"
		keylget data PROTOCOL.TYPE protocol; keylget data PROTOCOL.HOST host
		keylget data PROTOCOL.PORT port; keylget data PROTOCOL.PDLTYPE pdlType
		# 
		
		# Get the process name
		set klst [netcfgGetConnData $conn]
		if { $klst == ""} {
			# There is no NetConfig Data. Likely an inter-site routing thread_$conn
			# puts "no Process name found. Note path is: $HciRoot/$site/notes/NetConfig/destination_(threadName)"
			# puts "data: $data"
			set noteDir "$HciRoot/$site/notes/NetConfig/destination_"
		} else {
			set process [keylget klst PROCESSNAME]
			set noteDir "$HciRoot/$site/notes/NetConfig/$process/"
		}
		
		# set process [keylget [netcfgGetConnData $conn] PROCESSNAME]
		# puts "noteDir: $noteDir"
		
		# Get the "Desc:" line from the notes
		set note ""; set noteFile [concat $noteDir thread_$conn.notes ]
		# Remove the "Summary:" text
		
        regsub -all {\s} $noteFile {} noteFile
		# puts "noteFile: $noteFile"
		if {[file exists $noteFile]} {
			catch {exec grep Summary: $notesFile} note
			catch {exec grep Desc: $noteFile} note
		}
		
		# puts "site: $site, conn: $conn, protocol: $protocol, host: $host, port: $port"
		# Remove the "DESC:" text
		regsub -- {^Desc: ?} $note {} note
		
		# Don't include blank notes in the output
		if {$note == ""} {
			puts $site:$conn:$protocol:$host:$port
		} else {
			puts $site:$conn:$protocol:$host:$port:$note
		}
	}
		
	
}
