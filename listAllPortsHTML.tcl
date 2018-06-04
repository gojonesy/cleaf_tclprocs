#!/usr/bin/env tcl
# Traverses all Netconfigs and returns all in use Ports. Output should be redirected to an HTML file.
# 03/20/2017 - Jones - Created


global HciRoot; set debug 1

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sites /hci/cis6.1/integrator/adt_test }
set milConns {EMR_IA_REGB EMR_IA_REG}

if { $debug } { puts "[clock format [clock scan now] -format {%D %T}] - Site list: $sites" }
# Put together the html Styles in order for the output to have a prettier format.
set tableStyle "\ntable \{ \n\tfont-family: Trebuchet MS, Arial, Helvetica, sans-serif;\n\tborder-collapse: collapse;\n\twidth: 75%;\n\}\n"
set trStyle "tr:nth-child(even)\{background-color: #f2f2f2;\}\n\n tr:hover \{background-color: #ddd;\}\n"
set tdStyle "td, th \{ \n\t border: 1px solid #ddd;\n\t padding: 8px;\n\}\n"
set thStyle "th \{ \n\t padding-top: 12px; \n\t padding-bottom: 12px; \n\t text-align: left; \n\t background-color: #4CAF50; \n\t color: white;\n\}\n"

# Build the output header and styles. This also starts the "body" section of the html file
puts "<html><head><title>Cloverleaf Port Listing</title><style>$tableStyle$tdStyle$trStyle$thStyle</style></head><body>"


# Loop Over the Sites - 
foreach site $sites {
	# Sets up the heading for the site and then table with the table headings.
	puts "<h1>$site</h1><table><thead><tr><th>Connection</th><th>Host</th><th>Port</th></thead><tbody>"
	
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
		set protocol ""; set host ""; set port ""; set isServer 0
		# This starts a new table row
		puts "<tr>"
		# puts "conn: $conn"
		# Get the connection type and data
		set data [netcfgGetConnData $conn]
		# if {$conn == "EMR_IOR_RAD"} { puts "data: $data"}
		# if { $debug && $conn == "EXT_recv" } { puts "data: $data" }
		keylget data PROTOCOL.TYPE protocol; keylget data PROTOCOL.HOST host
		keylget data PROTOCOL.PORT port; keylget data PROTOCOL.PDLTYPE pdlType; keylget data PROTOCOL.ISSERVER isServer
		
		# Depending on the type of host, we build each cell of the row.
		if {$port != ""} {
			if {$isServer} {
				# get the server name
				set serverName "Listening On Port:"
				catch {exec netstat -an | grep $port | awk {{print $5}} | awk -F {:} {{print $1}}} serverIp opts
				set netStatus [lindex $opts 1];
				# if { !$netStatus } { puts "serverIP: [split $serverIp \n]" }
				if {[lindex [split $serverIp "\n"] 0] != "0.0.0.0" || [lindex [split $serverIp "\n"] 0] != "127.0.0.1" || !$netStatus } {
					catch {exec nslookup [lindex $serverIp 0] | awk -F {=} {{print $2}}} serverName sOpts
					set sStatus [lindex $sOpts 1]
					if { $sStatus } { 
						set serverName "Listening On Port:" 
					} 
				}
				
				# if { [regexp ]}
				if { [lsearch -exact $milConns $conn] > -1 } {
					# Need to add the thread to the milThreads List in order to output a separate Html file.
					puts "<td><b>$conn</b></td><td><b>[lindex [split [lindex $serverName 0] "."] 0]</b></td><td>$port</td></tr>"
				} else {
					puts "<td>$conn</td><td>[lindex [split [lindex $serverName 0] "."] 0]</td><td>$port</td></tr>"
				}
			} else {
				if { [lsearch -exact $milConns $conn] > -1 } {
					puts "<td><b>$conn</b></td><td><b>$host</b></td><td>$port</td></tr>"
				} else {
					puts "<td>$conn</td><td>$host</td><td>$port</td></tr>"
				}	
			}
		}		
			
	}
	# Finish the table for the site and place a horizontal rule
	puts "</tbody><table><hr>"
		
} 
# Finish the html document.
puts "</body></html>"

	