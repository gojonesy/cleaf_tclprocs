#!/usr/bin/env tcl
# Traverses all Netconfigs and returns all of the Millenium ports and outputs what domain they are pointed at in an html document.
# 03/29/2017 - Jones - Created
# 04/04/2017 - Jones - Updated to make the process more dynamic. Looks at Notes for the Environment description and does a lookup on IP address for outbounds

package require ip
global HciRoot; set debug 0
set environment [lindex $argv 0]

puts "environment: $environment"

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sites /hci/cis6.2/integrator/adt_test }
set timeNow [clock format [clock scan now] -format {%D %T}] 
if { $debug } { puts "$timeNow - Site list: $sites" }

# Setup the HTML output
# #### The output is placed into a new HTML file in the Contrib directory. This file is built with sections to hold the header and content lists.
set header "<h2>Cerner Millenium Domain Interface Status in TEST</h2>"
lappend header "<h3>Updated $timeNow</h3>"

set content "<table id=\"table\" data-toggle=\"table\" data-classes=\"table table-striped table-hover\" data-pagination=\"true\" data-search=\"true\" data-toolbar=\"#toolbar\">"
lappend content "<thead><tr><th data-field=\"thread\" data-sortable=\"true\">Thread</th><th data-field=\"source\" data-sortable=\"true\">Source</th><th data-field=\"dest\" data-sortable=\"true\">Destination</th><th data-field=\"type\" data-sortable=\"true\">Type</th><th data-field=\"env\" data-sortable=\"true\">Environment</th><th data-field=\"status\" data-sortable=\"true\">Status</th></thead><tbody id=\"listing\">"

# Traverse the sites and begin adding the EMR_I* and EMR_O* threads to the mapping keyed list
foreach site $sites {
	if {![file isdirectory $site]} {
	 	  continue 
	}
	
	set site [file tail $site]
	
	# Load the site's Netconfig
	eval [exec $HciRoot/sbin/hcisetenv -root tcl $HciRoot $site]
	netcfgLoad $HciRoot/$site/NetConfig
	
	# Get the Connection list
	set connList [lsort [netcfgGetConnList]]
	if {$debug} { puts "[clock format [clock scan now] -format {%D %T}] - ConnList: $connList" }
	
	########## Create a list of thread name exceptions. 
	set exceptions {DLBY_OR_RAD CSTM_OL_PACS MAGV_OR_MAM EMR25_IR_LAB RDS_IO_PHM BRID_OA_LAB CPTH_OM_MFN PHYREL_IX_XML}
	
	foreach conn $connList {
		# Check the thread name for the existence of the EMR_ string
		# puts "Lsearch: [lsearch -exact $exceptions $conn], Conn: $conn"
		if { [string match "EMR_O*" $conn] || [string match "EMR_I*" $conn] || [lsearch -exact $exceptions $conn] > -1 } {
			# Grab the thread's note and the Host name
			set host ""; set port ""; set note "";
			set data [netcfgGetConnData $conn]
			# puts "data: $data"
			keylget data PROTOCOL.HOST host; keylget data PROTOCOL.PORT port
			
			# Get the thread notes
			if { $data == ""} {
				# There is no NetConfig Data. Likely an inter-site routing thread_$conn
				set noteDir "$HciRoot/$site/notes/NetConfig/destination_"
			} else {
				set process [keylget data PROCESSNAME]
				set noteDir "$HciRoot/$site/notes/NetConfig/$process/"
			}
			# Get the "Desc:" line from the notes
			set noteFile [concat $noteDir thread_$conn.notes ]
			regsub -all {\s} $noteFile {} noteFile
			if {[file exists $noteFile]} {
				catch {exec grep Source: $noteFile} nSource
				catch {exec grep Dest: $noteFile} nDest
				catch {exec grep MsgType: $noteFile} nMsgType
			}
			# Remove the heading text
			regsub -- {^Source: ?} $nSource {} nSource; regsub -- {^Dest: ?} $nDest {} nDest; regsub -- {^MsgType: ?} $nMsgType {} nMsgType;
			
			# Check for grep errors
			set errorMsg "child process exited abnormally"; set defaultMsg ""
			if { [string match $errorMsg $nSource] } { set nSource $defaultMsg }
			if { [string match $errorMsg $nDest] } { set nDest $defaultMsg }
			if { [string match $errorMsg $nMsgType] } { set nMsgType $defaultMsg }
			# set serverIp ""
			# Get the connection's IP and Port and find the DNS Name of the server portion of the connection:
			# There is a difference between I and O threads. 
			if { [string match "EMR_I*" $conn]} {
				catch {exec netstat -an | grep $port | awk {{print $5,$6}} } serverIp opts
				catch {exec nslookup [lindex [split [lindex $serverIp 0] {:}] 0] | awk -F {=} {{print $2}}} serverName sOpts
			} elseif { [string match "EMR_O*" $conn ] || [lsearch -exact $exceptions $conn] > -1  } {
				# Make sure we have a valid IP address prior to doing the NSLookup - This uses the IP Tcl package
				catch {exec netstat -an | grep $port | awk {{print $5,$6}} } serverIp opts
				# if {[lindex $serverIp 1] != "ESTABLISHED"} {puts "Site: $site - Conn: $conn - serverIp: [lindex $serverIp 1]"}
				if {[::ip::version $host] == 4} {
					catch {exec nslookup $host | awk -F {=} {{print $2}}} serverName sOpts
				} else {
					# Utilize the $host value
					set serverName $host
				}
				
			}
			
			#puts "Conn: $conn - serverIp: $serverIp"
			
			
			# See if the grep command failed. Generally means that the connection is not active.
			if {[lindex [split [lindex $serverName 0] {.}] 0] == "child" } {
				set serverName "{}"
			}
			# Complete the connection output.
			# puts ""
			if {[lindex $serverIp 1] == "ESTABLISHED" } {
				lappend content "<tr class=success><td>$conn</td><td>$nSource</td><td>$nDest</td><td>$nMsgType</td>"
				lappend content "<td>[lindex [split [lindex $serverName 0] {.}] 0]</td><td>[lindex $serverIp 1]</td></tr>"
			} else {
				lappend content "<tr class=danger><td>$conn</td><td>$nSource</td><td>$nDest</td><td>$nMsgType</td>"
				lappend content "<td>[lindex [split [lindex $serverName 0] {.}] 0]</td><td>DISCONNECTED</td></tr>"
			}
			
		}
		
	
	}
	
}

lappend content "</tbody></table>"

# Copy the existing clDocsBase.html file to a new file
set baseFile "/hci/cis6.2/integrator/contrib/html/clDocsBase.html"; set outputFile "/hci/cis6.2/integrator/contrib/html/cernerStatus.html"
set base [open $baseFile r]; set output [open $outputFile w]

# Read in the base file and copy each line to the outputFile
while {[gets $base line] != -1} {
	# puts "line: $line"
	if { [string match "<!--- ### Header ### -->" [string trimleft $line]]} {
		puts $output [join $header \n]
	} elseif { [string match "<!--- ### MainContent ### -->" [string trimleft $line]] } {
		puts $output [join $content \n]
	} elseif { [string match "<!--- ### CSS ### -->" [string trimleft $line]] } {
		puts $output [join $css \n]
	} elseif { [string match "<!--- ### JS ### -->" [string trimleft $line]] } {
		puts $output [join $js \n]
	} else {
		puts $output $line
	}
}

close $base; close $output


