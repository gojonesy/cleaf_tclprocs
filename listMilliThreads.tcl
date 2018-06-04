#!/usr/bin/env tcl
package require ip
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
		if { [string match "EMR_O*" $conn] || [string match "EMR_I*" $conn] } {
			# puts "conn: $conn"
			# Get the connection type and data
			set data [netcfgGetConnData $conn]
			# puts "data: $data"
			keylget data PROTOCOL.TYPE protocol; keylget data PROTOCOL.HOST host
			keylget data PROTOCOL.PORT port; keylget data PROTOCOL.PDLTYPE pdlType
			
			# Get the process name
			if { $data == ""} {
				# There is no NetConfig Data. Likely an inter-site routing thread_$conn
				set noteDir "$HciRoot/$site/notes/NetConfig/destination_"
			} else {
				set process [keylget data PROCESSNAME]
				set noteDir "$HciRoot/$site/notes/NetConfig/$process/"
			}
			# puts "process: $process"
			# Get the "Desc:" line from the notes
			set note ""
			set noteFile [concat $noteDir thread_$conn.notes]
	
			regsub -all {\s} $noteFile {} noteFile
			if {[file exists $noteFile]} {
				catch {exec grep Source: $noteFile} nSource
				catch {exec grep Dest: $noteFile} nDest
				catch {exec grep MsgType: $noteFile} nMsgType
			}
			# Remove the heading text
			regsub -- {^Source: ?} $nSource {} n; regsub -- {^Dest: ?} $nDest {} n; regsub -- {^Type: ?} $nMsgType {} n; 
			
			
			
			# Don't include blank notes in the output
			# puts "note: $note"
			if {![lsearch $note ""]} {
				puts "\t$site:$conn:$protocol:$host:$port"
			} else {
				puts "\t$site:$conn:$protocol:$host:$port:$nSource:$nDest:$nMsgType"
			}
			# puts [::ip::version $host]
		}
	}
		
	
}
