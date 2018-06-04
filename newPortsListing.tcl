#!/usr/bin/env tcl
# Traverses all Netconfigs and returns all in use Ports. Output should be redirected to an HTML file.
# 03/20/2017 - Jones - Created


global HciRoot; set debug 0
set environment "TEST"

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sites /hci/cis6.1/integrator/adt_test }

if { $debug } { puts "[clock format [clock scan now] -format {%D %T}] - Site list: $sites" }


# Trying some new table stuff.
# Setup the HTML output
puts "<!DOCTYPE html><html lang=en><head><title>Cloverleaf Port Listing - $environment</title>"
puts "<script type=\"text/javascript\" src=\"js/jquery-1.12.4.min.js\"></script>\n"
puts "<link type=text/css rel=stylesheet href=css/bootstrap.min.css>\n<style>\ntr:nth-child(1) > th:hover \{ \n\t cursor: pointer; \n\}\n</style>\n</head>"
puts "<body><div class=\"container container-responsive\"><div class=\"row\"><div class=\"col-md-1\"></div><div class=\"col-md-10\">"
puts "<h1>Cloverleaf Port Listing - $environment</h1><br>"
puts "<h2>Updated [clock format [clock scan now] -format {%D %T}] </h2><hr>"
puts "<table data-toggle=\"table\" data-sort-name=\"port\">"
puts "<thead><tr><th data-field=\"site\" data-sortable=\"true\">Site</th><th id=\"thread\">Thread</th><th id=\"port\">Port</th><th id=\"host\">Host</th></thead><tbody id=\"listing\">"



# Loop Over the Sites - 
foreach site $sites {
	# Sets up the heading for the site and then table with the table headings.
	
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
		
		
		puts "<td>$site</td><td>$conn</td><td>$port</td><td>$host</td>"
			
	}

} 
# Finish the html document.
puts "</tbody><table><hr></div></div class=\"col-md-1\"></div></div>"
puts "<script type=\"text/javascript\" src=\"js/table_filter.js\"></script>"
puts "</body></html>"

	