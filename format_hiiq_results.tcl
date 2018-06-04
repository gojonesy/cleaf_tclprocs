#######################################################################################
# Name:         format_hiiq_results.tcl   
# Purpose:      
#
# UPoC type: Pre Xlate 
# Args:         tps keyedlist containing the following keys:
#               MODE    run mode ("start", "run" or "time")
#               MSGID   message handle
#               ARGS    user-supplied arguments:
#               #
# Returns: tps disposition list:
#          CONTINUE - Message was processed normally - continue into engine.
#          ERROR - Message processing failed - put message into the error database.
#
# This proc the orders messagees for ANG type
######################################################################################

proc format_hiiq_results { args } {
        global HciConnName

        keylget args MODE mode        ;# Fetch mode
        keylget args CONTEXT context   ;# Fetch context


        #    if { ! [info exists HciConnName] } {
        #        set HciConnName "UNKNOWN_TD"
        #    }

        set dispList {}                             ;# Nothing to return

        switch -exact -- $mode {
                start {
                        # Perform special init functions
                        # N.B.: there may or may not be a MSGID key in args
                }

                run {
		keylget args MSGID mh               ;# Fetch the MSGID
		set msg [msgget $mh]                  ;# Get the Message Handle

		set outbuf {}
		# Do this reg sub to put right repeat separator in signature line
		regsub -all {\\.br\\} $msg {~} msg
		# Now we need to determine our field and sub components
		set field_sep [csubstr $msg 3 1]      ;# HL7 field separator
		set sub_sep [csubstr $msg 4 1]        ;# HL7 subfield separator
		set sub_sub_sep [csubstr $msg 7 1]    ;# HL7 sub-subfield separator
		set rep_sep [csubstr $msg 5 1]        ;# HL7 repetition separator
		set segmentList [split $msg \r]            
		set msgDisp "KILL"
		 
		#Set exam and room variables
		set obrseg [lsearch -regexp -inline $segmentList ^OBR]
		set obr_4 [lindex [split $obrseg $field_sep] 4]
		set exam [lindex [split $obr_4 $sub_sep] 0]
		set room [lindex [split $obrseg $field_sep] 21]
		#Set exam filter for Cath exams.
		#THIS IS A POSITIVE FILTER - THESE TESTS ARE INCLUDED
		if [cequal [crange $exam 0 1] CT] {
			switch -regex -- $exam {
			   ^(CTAB|CTAD|CTABP|CTB|CTCAFIB|CTCAL|CTCERM|CTCH|CTCO|CTCP|CTCYST|CTCYST|CTDM|CTDR|CTLDA|CTLUM|CTNRCT|CTRFV|CTNRLS|CTPI|CTTDA|CTTHO|CTSA|CTSI) {set exam "CATH"}
			   default {set exam "NOPASS"}
			}
		}
		#Set exam filter for Ultrasound exams.
		#THIS IS A NEGATIVE FILTER - THESE TESTS ARE EXCLUDED
		if [cequal [crange $exam 0 1] US] {
			switch -regex -- $exam {
			   ^(USABP|USBA|USBB|USBCA|USBCB|USBCLT|USBCLRT|USBD|USBLF|USBRF|USBG|USBI|USBN|USBR1|USBR2|USBLB|USBLL|USBLR|USI|USGM|USGP) {set exam "NOPASS"}
			   default {set exam "ULTRASOUND"}
			}
		}
		#Start the Exam/Room filter logic
		#Valid exams not assigned to a valid room are filtered
		#NOPASS exams are killed
		#echo "Exam: $exam"
		#echo "Room: $room"
		switch -regex -- $exam {
			^(ANG|AVB) {switch -regex -- $room {
		   		^(MA|MC|MF|MI|MN|MU) {set msgDisp "CONTINUE"; set facility 10}}
			       }		 
  			CATH {switch -regex -- $room {
				^(MA|MC|MF|MI|MN|MU) {set msgDisp "CONTINUE"; set facility 11}}
			       }
			^(DMY|DSP) {switch -regex -- $room {
					^(MA|MC|MF|MI|MN|MU) {set msgDisp "CONTINUE"; set facility 13}}
			       }
			ULTRASOUND {switch -regex -- $room {
				^(BU|MA|MC|MF|MI|MN|MU) {set msgDisp "CONTINUE"; set facility 12}}
			       }
			NOPASS {set msgDisp "KILL"}
   			}
		#Pull out the contents of OBR.25 to set result status
		set obrseg [lsearch -regexp -inline $segmentList ^OBR]
		set obr_25 [lindex [split $obrseg $field_sep] 25]
		if [cequal $obr_25 "F"] {
			set result_status "F"
		} elseif [cequal $obr_25 "8"] { 
			set result_status "A"
		} else {
			set result_status ""
		}		   
		#Pull out the contents of OBX.5 & set counter 		   
		set obxseg [lsearch -regexp -inline $segmentList ^OBX]
		set obx_5 [lindex [split $obxseg $field_sep] 5]
		set obx_line_count 0
		   
		#Begin segment manipulations
		foreach segment $segmentList {
#PV1 - change location based on exam type
			if [cequal [crange $segment 0 2] PV1] {
				set fieldList [split $segment $field_sep]
				set pv1_3_list [split [lindex $fieldList 3] $sub_sep]
				catch {set pv1_3_list [lreplace $pv1_3_list 3 3 $facility]}
				set pv1_3 [join $pv1_3_list $sub_sep]
				catch {set fieldList [lreplace $fieldList 3 3 $pv1_3]}
				set segment [join $fieldList $field_sep]
				append outbuf ${segment}\r
#OBR     	
			} elseif [cequal [crange $segment 0 2] OBR] {  	
				set fieldList [split $segment $field_sep]
				set obr_20_list [split [lindex $fieldList 20] $sub_sep]
				set accession [string trimleft [lindex $obr_20_list 0] "0000020"]
				catch {set fieldList [lreplace $fieldList 3 3 $accession]}
				set obr_25 [lindex $fieldList 25]
				if {![cequal $obr_25 F] && ![cequal $obr_25 8]} { 
					set msgDisp "KILL"
				} 
				set segment [join $fieldList $field_sep]
				append outbuf ${segment}\r  
#OBX
			} elseif [cequal [crange $segment 0 2] OBX] {  	
				set fieldList [split $segment $field_sep]
				if [expr [llength [split $obx_5 $rep_sep]] > 0] {
					foreach line [split $obx_5 $rep_sep] {
					#CREATE INDIVIDUAL OBX SEGMENTS
						incr obx_line_count
						set newFieldList [list OBX $obx_line_count "ST" "REPORT" 1 $line {} {} {} {} {} $result_status {} {} {} {} {}]
						set newsegment [join $newFieldList $field_sep]
						append outbuf ${newsegment}\r
					}
				} else {  
					append outbuf ${segment}\r  
				}
#NTE        	
			} elseif [cequal [crange $segment 0 2] NTE] {
				set fieldList [split $segment $field_sep]
				set nte_3 [lindex $fieldList 3]
				if ![cequal $nte_3 ""] {
					#Create blank line before signature line
					incr obx_line_count
					set line ""
					set newFieldList [list OBX $obx_line_count "ST" "REPORT" 1 $line {} {} {} {} {} $result_status {} {} {} {} {}]
					set newsegment [join $newFieldList $field_sep]
					append outbuf ${newsegment}\r
					# Loop through the NTE signature line data and create individual OBXs for them
					foreach line [split $nte_3 $rep_sep] {
						incr obx_line_count
						set newFieldList [list OBX $obx_line_count "ST" "REPORT" 1 $line {} {} {} {} {} $result_status {} {} {} {} {}]
						set newsegment [join $newFieldList $field_sep]
						append outbuf ${newsegment}\r
					}
				}
#Z-segments - Suppress        	
			} elseif [cequal [crange $segment 0 0] Z] {  
#OTHER                                  
			} else {
				append outbuf ${segment}\r
			}
		}
		regsub -all {""} $outbuf {} outbuf
		set outbuf [string trimright $outbuf "\r"]
		set outbuf "$outbuf\r"
		msgset $mh $outbuf
		lappend dispList "$msgDisp $mh"
                }
	      time {
                    # Timer-based processing
                    # N.B.: there may or may not be a MSGID key in args
                }
                shutdown {
                    # Doing some clean-up work 
                }
                default {
                    error "Unknown mode '$mode' in format_hiiq_results"
                }
        }

return $dispList
}
