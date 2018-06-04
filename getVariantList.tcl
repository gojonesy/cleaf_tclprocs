#!/usr/bin/env tcl
# Locates all Variants that are in use and where they are in use.
# 04/10/2017 - Jones - Created

global HciRoot; set debug 0
set environment [lindex $argv 0]

# List exclusions
set siteExcludes {helloworld test}

# Get the sites form the server.ini
set sites [string map {environs= {}} [exec grep environs $HciRoot/server/server.ini]]
set sites [lsort [split $sites \;]]

if { $debug } { set sitePath /hci/cis6.2/integrator/adt_test; set sites /hci/cis6.2/integrator/adt_test; }
set timeNow [clock format [clock scan now] -format {%D %T}] 
if { $debug } { puts "$timeNow - Site list: $sites" }

# #### The output is placed into a new HTML file in the Contrib directory. This file is built with sections to hold the header and content lists.
set header " <h2>Cloverleaf Variant Usage $environment</h2>" 
lappend header "<h3>Updated $timeNow</h3>"

set content "<table id=\"table\" data-toggle=\"table\" data-classes=\"table table-striped table-hover table-responsive\" data-pagination=\"true\" data-search=\"true\" data-toolbar=\"#toolbar\">" 
lappend content "<thead><tr><th data-field=\"site\" data-sortable=\"true\">Site</th><th data-field=\"version\" data-sortable=\"true\">Version</th><th data-field=\"variant\" data-sortable=\"true\">Variant</th><th data-field=\"location\" data-sortable=\"true\">Location</th><th data-field=\"count\" data-sortable=\"true\" data-sorter=\"numberSorter\">Count</th></thead><tbody id=\"listing\">"

# Traverse the formats/hl7 Directory and return a liting of all of the different variant versions. 
foreach site $sites {
	catch {exec ls -l $site/formats/hl7/ | awk {{print $9}} } versions options
	
	set status [lindex $options 1]
	if {!$status} {
		puts "$site"
		# Grab all of the version names from "site/formats/hl7/"
		foreach version $versions {
			puts "$version"
			catch {exec ls -l $site/formats/hl7/$version/ | awk {{print $9}} } variants voptions
			# Grab each variant from each version directory.
			if {![lindex $voptions 1]} {
				foreach variant $variants {
					# puts "$variant"
					
					# Now search for each variant in all Xlates for the site.
					catch {exec grep -Rilw --include=*.xlt $variant $site/Xlate/} xresults xoptions
					lappend content "<tr><td>[lindex [split $site /] 4]</td><td>$version</td><td>$variant</td>"
					if {![lindex $xoptions 1]} {
						lappend content "<td><ul>"
						foreach result $xresults {
							lappend content "<li>[lindex [split $result /] 6]</li>"
						}
						lappend content "</td><td>[llength $xresults]</td>"
					} else {
						lappend content "<td>Not in Use</td><td>0</td>"
					}
				}
			}
		}
	}
	
}

lappend content "</tbody></table>"

# Copy the existing clDocsBase.html file to a new file
set baseFile "/hci/cis6.2/integrator/contrib/html/clDocsBase.html"; set outputFile "/hci/cis6.2/integrator/contrib/html/variantUsage.html"
set base [open $baseFile r]; set output [open $outputFile w]

# Read in the base file and copy each line to the outputFile
while {[gets $base line] != -1} {
	# puts "line: $line"
	# Need to modify the links for in subdirectories:

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