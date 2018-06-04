#!/usr/bin/env tcl
# Locates all Xlates that are not in use and moves them to the backup directory
# 09/15/2017 - Jones - Created
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
#set sites cac_test

if { $debug } { set sitePath /hci/cis6.1/integrator/dft_test; set sites /hci/cis6.1/integrator/dft_test }
set timeNow [clock format [clock scan now] -format {%D %T}]
if { $debug } { puts "$timeNow - Site list: $sites" }

# Setup the manifest email:
set emailBody "<h2>Results of $scriptName run from $timeNow</h2>"

foreach site $sites {

    set sitePath $site
    set site [file tail $site]

    # Get the Xlate list
    catch {exec ls -l $sitePath/Xlate | awk {{ print $9 }} } listing options

    lappend emailBody "<h3><strong>$site</strong></h3><ul>"

    # Load the Site's NetConfig
    eval [exec $HciRoot/sbin/hcisetenv -root tcl $HciRoot $site]
    netcfgLoad $HciRoot/$site/NetConfig
    set connList [lsort [netcfgGetConnList]]

    # Ensure that backup directory exists
    catch {eval [exec mkdir /home/hci/backup/$site]} messages options
    catch {eval [exec mkdir /home/hci/backup/$site/Xlate]} messages options

    foreach xlate $listing {
        puts "xlate: $xlate"
        catch {exec grep -Rilw $xlate $sitePath/NetConfig} xresults xoptions
        # lappend content "<li>$xlate</li></td>"
        #puts "results: $xresults"
        set status [lindex $xoptions 1]
        if { $status } {
            # Move the file to the backup directory
            puts "Moving $xlate ...."
            if {!$debug} {eval [exec mv $sitePath/Xlate/$xlate /home/hci/backup/$site/Xlate/$xlate]}
            lappend emailBody "<li>$xlate</li>"

        }
    }
    lappend emailBody "</ul>"
}

# Send out a manifest in an email. This will only generate when ran.
sendMail [join $emailBody \n] "text/html" "Manifest from $scriptName script run $timeNow" $emailTo
