######################################################################
# Name:         audit_idph_251.tcl   
# Purpose:      
#
# UPoC type: Called 
# Args: dati - date/time (MSH-7), id {PID-3}, name (PID-5), dob (PID-7), desc (RXA-5.1), dose (RXA-7)
#               
# Returns: outstr (Formatted string for audit file)
#
# Written by Mike Keys, November 23rd, 2011
# version 1.0
#
# This proc creates an audit file for IDPH Immunizations


proc audit_idph_251 {dati id name dob desc dose dose_units} {
               	
                        #Initialize Variables
				set sub_sep "^"
				set dati $dati
				set id [lindex [split $id $sub_sep] 0] 
				set fn [lindex [split $name $sub_sep] 1]
				set ln [lindex [split $name $sub_sep] 0]
				set mn [lindex [split $name $sub_sep] 2]
				set dob $dob 
				set desc [lindex [split $desc $sub_sep] 0]
				#set quan [lindex [split $dose $sub_sep] 0]
				#set units [lindex [split $dose $sub_sep] 1]
				
				#Format the date and time stamp
				set docmonth [crange $dati 4 5]
				set docday [crange $dati 6 7]
				set docyear [crange $dati 0 3]
				set dochour [crange $dati 8 9]
				set docminute [crange $dati 10 11]
				set newdatestr "$docmonth/$docday/$docyear $dochour:$docminute"

				#Format the DOB
				set birthmonth [crange $dob 4 5]
				set birthday [crange $dob 6 7]
				set birthyear [crange $dob 0 3]
				set newbirthstr "$birthyear/$birthmonth/$birthday"
				
				#Format the name
				if [cequal "\"\"" $mn] {
					set fullname "$fn $ln"
				} else {
					set fullname "$fn $mn $ln"
				}

				#Format the dose
				#set newdose "$quan$units"				

				#Set tab stops
				if [expr [string length $fullname] <= 18] {
					set tab "\t"
				} else {
					set tab "\t\t"
				}
							
				#BUILD AUDIT FILE
				set outstr "$newdatestr\t$id\t$fullname$tab$newbirthstr\t$desc\t$dose $dose_units"
 
        return $outstr
}
