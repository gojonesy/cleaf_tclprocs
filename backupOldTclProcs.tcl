#!/usr/bin/env tcl
# # Locates all tclprocs that are not in use and moves them to the backup directory
# 09/15/2017 - Jones - Created
# 01/09/2018 - Jones - Added logic to locate tcl references in other procs.
# 02/20/2018 - Jones - Updated to add an email manifest to the script run.

global HciRoot; set debug 1
set environment [lindex $argv 0]

set scriptName $argv0
set emailTo "InterfaceTeam@mhsil.com"
if {$debug} {set emailTo "jones.justin@mhsil.com" }

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sites /hci/cis6.1/integrator/adt_test }
set timeNow [clock format [clock scan now] -format {%D %T}]
if { $debug } { puts "$timeNow - Site list: $sites" }

if { $debug } { puts "[clock format [clock scan now] -format {%D %T}] - Site list: $sites" }

# Setup the manifest email:
set emailBody "<h2>Results of $scriptName run from $timeNow</h2>"
# Loop Over the Sites -
foreach site $sites {

    puts "[clock format [clock scan now] -format {%D %T}] - Starting run for $site"
    if {![file isdirectory $site]} {
          continue
    }
    # Don't move anything from the master site.
    if {$site == "/hci/cis6.1/integrator/clvrtest"} {
      continue
    }

    lappend emailBody "<h3><strong>$site</strong></h3><ul>"

    set tclindexPath "$site/tclprocs/tclIndex"; set sitePath $site
    set site [file tail $site]

    # Open the tclindex and begin to parse
    set indexHandle [open $tclindexPath]
    set text [read $indexHandle]; close $indexHandle
    set lines [split $text \n]
    # # Load the site's Netconfig in order to search for the proc in the Netconfig
    eval [exec $HciRoot/sbin/hcisetenv -root tcl $HciRoot $site]
    netcfgLoad $HciRoot/$site/NetConfig
    set connList [lsort [netcfgGetConnList]]


     # Ensure that backup directory exists
    catch {eval [exec mkdir /home/hci/backup/$site]} messages options
    catch {eval [exec mkdir /home/hci/backup/$site/tclprocs]} messages options

    # Go through the tclindex
    foreach line $lines {
        if { [string match "*set auto_index*" $line] } {
            set searchPlace [lindex [split $line " "] 1]
            # Get just the proc name
            set procName [string range $searchPlace [expr [string first ( $searchPlace] + 1] [expr [string first ) $searchPlace] -1]]
            set status 0; set xstatus 0; set tstatus 0; set tcstatus 0
            # Now, Search for the procName in all NetConfigs
            # puts "grep -Ril $procName $sitePath/NetConfig"
            catch {exec grep -Rilw $procName $sitePath/NetConfig} results options
            # Now, search all of the Xlates
            # puts "grep -Ril --include=\"*.xlt\" $procName $sitePath/Xlate/"
            catch {exec grep -Rilw --include=*.xlt $procName $sitePath/Xlate/} xresults xoptions
            # Now, search in all other tcl procs for a reference to the proc
            # puts "grep -Ril --include=\"*.tcl\" $procName $sitePath/tclprocs/"
            # puts "grep -Ril --include=\"*.tcl\" $procName.tcl $sitePath/tclprocs/"
            catch {exec grep -Rilw --include=*.tcl $procName $sitePath/tclprocs/} tresults toptions
            catch {exec grep -Rilw --include=*.tcl $procName.tcl $sitePath/tclprocs/} tcresults tcoptions

            set status [lindex $options 1]
            set xstatus [lindex $xoptions 1]
            set tstatus [lindex $toptions 1]
            set tcstatus [lindex $tcoptions 1]

            # if {$debug} { puts "$site - $procName - Netconig: $results : $options" }
            # if {$debug} { puts "$site - $procName - Xlate: $xresults : $xoptions" }
            # if {$debug} { puts "$site - $procName - Tcl Procs: $tresults : $toptions" }
            # if {$debug} { puts "$site - $procName - Tcl Procs .tcl: $tcresults : $tcoptions" }
            if { $status && $xstatus } {
                # Backup the unused tcl proc
                puts "Moving $procName ...."
                if {!$debug} {catch {eval [exec mv $sitePath/tclprocs/$procName.tcl /home/hci/backup/$site/tclprocs/$procName.tcl]}}
                lappend emailBody "<li>$procName</li>"
            }


        }
    }

    # Remake the tclindex.?
    eval [exec mktclindex -d $sitePath/tclprocs/]

    lappend emailBody "</ul>"
}

# Send out a manifest in an email. This will only generate when ran.
sendMail [join $emailBody \n] "text/html" "Manifest from $scriptName script run $timeNow" $emailTo
