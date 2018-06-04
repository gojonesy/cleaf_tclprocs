#!/usr/bin/env tcl
# Locates all Variants that are not in use and moves them to the backup directory
# 09/20/2017 - Jones - Created
# 02/20/2018 - Jones - Updated to add an email manifest to the script run. 

global HciRoot; set debug 1

set scriptName $argv0
set emailTo "InterfaceTeam@mhsil.com"
if {$debug} {set emailTo "jones.justin@mhsil.com" }

set environment [lindex $argv 0];

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]
#set sites cac_test

if { $debug } { set sitePath /hci/cis6.1/integrator/dft_prod; set sites /hci/cis6.1/integrator/dft_prod }
set timeNow [clock format [clock scan now] -format {%D %T}]
if { $debug } { puts "$timeNow - Site list: $sites" }

# Setup the manifest email:
set emailBody "<h2>Results of $scriptName run from $timeNow</h2>"

# Traverse the formats/hl7 Directory and return a liting of all of the different variant versions.
foreach site $sites {
    catch {exec ls -l $site/formats/hl7/ | awk {{print $9}} } versions options

    set status [lindex $options 1]
    if {!$status} {
        puts "$site"
        lappend emailBody "<h3><strong>$site</strong></h3><ul>"
        # Grab all of the version names from "site/formats/hl7/"
        foreach version $versions {
            puts "$version"
            catch {exec ls -l $site/formats/hl7/$version/ | awk {{print $9}} } variants voptions

            # Grab each variant from each version directory.
            if {![lindex $voptions 1]} {
                foreach variant $variants {
                    # Now search for each variant in all Xlates for the site.
                    catch {exec grep -Rilw --include=*.xlt $variant $site/Xlate/} xresults xoptions

                    if {[lindex $xoptions 1]} {
                        puts "$variant - not in use!"
                        lappend emailBody "<li>$variant</li>"
                        # Ensure that the site and formats/hl7 and version directories exist
                        catch {eval [exec mkdir /home/hci/backup/[file tail $site]]} messages options
                        catch {eval [exec mkdir /home/hci/backup/[file tail $site]/formats]} messages options
                        catch {eval [exec mkdir /home/hci/backup/[file tail $site]/formats/hl7]} messages options.
                        catch {eval [exec mkdir /home/hci/backup/[file tail $site]/formats/hl7/$version]} messages options

                        # Tar up the variant
                        if {!$debug} {catch {eval [exec tar czf /home/hci/backup/[file tail $site]/formats/hl7/$version/$variant.tar.gz -C /hci/cis6.1/integrator/[file tail $site]/formats/hl7/$version/ $variant]}}

                        # Remove the Variant
                        if {!$debug} {catch {eval [exec rm -r /hci/cis6.1/integrator/[file tail $site]/formats/hl7/$version/$variant]}}

                    }
                }
            }
        }
    }
    lappend emailBody "</ul>"
}

sendMail [join $emailBody \n] "text/html" "Manifest from $scriptName script run $timeNow" $emailTo
