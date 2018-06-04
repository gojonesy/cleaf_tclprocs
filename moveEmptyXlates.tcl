#!/usr/bin/env tcl
# Locates all Xlates that are not in use and moves them to the backup directory
# 09/15/2017 - Jones - Created

global HciRoot; set debug 1

set environment [lindex $argv 0]

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]
set sites adt_test

if { $debug } { set sitePath /hci/cis6.1/integrator/adt_test }
set timeNow [clock format [clock scan now] -format {%D %T}] 
if { $debug } { puts "$timeNow - Site list: $sites" }

foreach site $sites {

    set sitePath $site
    set site [file tail $site]
    # Get the Xlate list
    catch {exec ls -l $sitePath/Xlate | awk {{ print $9 }} } listing options
    
    # Load the Site's NetConfig
    eval [exec $HciRoot/sbin/hcisetenv -root tcl $HciRoot $site]
    netcfgLoad $HciRoot/$site/NetConfig
    set connList [lsort [netcfgGetConnList]]

    foreach xlate $listing {
        catch {exec grep -Rilw $xlate $sitePath/NetConfig} xresults xoptions
        # lappend content "<li>$xlate</li></td>"
        
        set status [lindex $xoptions 1]
        puts "Status: $status"
    }
}
