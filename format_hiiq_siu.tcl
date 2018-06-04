########################################################################################
# Name:         format_hiiq_siu.tcl   
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
# This proc formats the accession number and filters no applicable schedule messages.
########################################################################################

proc format_hiiq_siu { args } {
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

		# Now we need to determine our field and sub components
		set field_sep [csubstr $msg 3 1]      ;# HL7 field separator
		set sub_sep [csubstr $msg 4 1]        ;# HL7 subfield separator
		set sub_sub_sep [csubstr $msg 7 1]    ;# HL7 sub-subfield separator
		set rep_sep [csubstr $msg 5 1]        ;# HL7 repetition separator
		set segmentList [split $msg \r]            
		set msgDisp "KILL"
		# Count the number of ZBX segments
		set zbx_count [llength [lsearch -all -regexp $segmentList {^ZBX}]]

						
		#Grab order number from SCH segment
		set schseg [lsearch -regexp -inline $segmentList ^SCH]
		set sch_5 [lindex [split $schseg $field_sep] 5]
		
		#Set exam and room variables
		set aigseg [lsearch -regexp -inline $segmentList ^AIG]			
		set aig_3 [lindex [split $aigseg $field_sep] 3]
		set room [lindex [split $aig_3 $sub_sep] 0]
		set aisseg [lsearch -regexp -inline $segmentList ^AIS]
		set ais_3 [lindex [split $aisseg $field_sep] 3]
		set exam [lindex [split $aisseg $field_sep] 3]
		#Set exam filter for Cath exams.
		#THIS IS A POSITIVE FILTER - THESE TESTS ARE INCLUDED
		if [cequal [crange $exam 0 1] CT] {
			switch -regex -- $exam {
			   ^(CTAB|CTAD|CTABP|CTB|CTCAFIB|CTCAL|CTCERM|CTCH|CTCO|CTCP|CTCYST|CTCYST|CTDM|CTDR|CTLDA|CTLUM|CTNRCT|CTPI|CTRFV|CTNRLS|CTTDA|CTTHO|CTSA|CTSI) {set exam "CATH"}
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
				^(MA|MI|MN) {set msgDisp "CONTINUE"; set facility 10}}
			       }			
		          CATH {switch -regex -- $room {
				^(MC) {set msgDisp "CONTINUE"; set facility 11}}
			       }
			^(DMY|DSP) {switch -regex -- $room {
				^(MF) {set msgDisp "CONTINUE"; set facility 13}}
			       }
			ULTRASOUND {switch -regex -- $room {
				^(BU|MU) {set msgDisp "CONTINUE"; set facility 12}}
			       }
			NOPASS {set msgDisp "KILL"}
   			}
		#Begin segment manipulations
		foreach segment $segmentList {
#NTE - Suppress
			if [cequal [crange $segment 0 2] NTE] {
#ZBX     	
			} elseif [cequal [crange $segment 0 2] ZBX] {
				set fieldList [split $segment $field_sep]
				set zbx_id [lindex $fieldList 1]
				if [cequal $zbx_id $zbx_count] {
					#Write out the last segment
					set segment [join $fieldList $field_sep]
					append outbuf ${segment}\r
					#Create the order id segment
					incr zbx_id
					set newFieldList [list ZBX $zbx_id "ID" "Order ID^Order ID" {} $sch_5 ]
					set newsegment [join $newFieldList $field_sep]
					append outbuf ${newsegment}\r
				} else {
					set segment [join $fieldList $field_sep]
					append outbuf ${segment}\r
				}
#PV1 - change location based on exam type
			} elseif [cequal [crange $segment 0 2] PV1] {
				set fieldList [split $segment $field_sep]
				set pv1_3_list [split [lindex $fieldList 3] $sub_sep]
				catch {set pv1_3_list [lreplace $pv1_3_list 3 3 $facility]}
				set pv1_3 [join $pv1_3_list $sub_sep]
				catch {set fieldList [lreplace $fieldList 3 3 $pv1_3]}
				set segment [join $fieldList $field_sep]
				append outbuf ${segment}\r
#AIL - change location based on exam type
			} elseif [cequal [crange $segment 0 2] AIL] {
				set fieldList [split $segment $field_sep]
				set ail_3_list [split [lindex $fieldList 3] $sub_sep]
				catch {set ail_3_list [lreplace $ail_3_list 3 3 $facility]}
				set ail_3 [join $ail_3_list $sub_sep]
				catch {set fieldList [lreplace $fieldList 3 3 $ail_3]}
				set segment [join $fieldList $field_sep]
				append outbuf ${segment}\r
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
		error "Unknown mode '$mode' in format_hiiq_siu"
	      }
	}
return $dispList
}
