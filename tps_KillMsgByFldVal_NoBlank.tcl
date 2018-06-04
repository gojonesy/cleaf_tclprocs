#######################################################################################
# Name:		tps_KillMsgByFldVal_NoBlank
# Author:	Barb Dozier, Brandon Schutt
# Date:	 	9/1/03   
# Purpose:	Verifies the data within thE Message.  Kills those that are not wanted.
# UPoC type:	sms_ib_data or pre_xlt
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#		segid - the name of the segment within which data resides
#		fieldid - the number of the field associated with the data
#		fieldcomp - the component number within the field - default
#			to first subcomponent
#		goodlist - data to compare message data against. If data
#			within message NOT PART of good list then kill msg.
#		badlist - data to compare message data against.  If data
#			within message PART of badlist then kill msg.
#		hosp - the hospital to which these values are valid
#
# Returns: tps CONTINUE or KILL message
# Update:  accucare doesn't accept a blank field
#########################################################################################
proc tps_KillMsgByFldVal_NoBlank { args } {

    keylget args MODE mode        	

    set dispList {}

    switch -exact -- $mode {
    	start {
    		return ""
    	}
    	
    	run {
    		#setting variables
    		set goodlist ""
    		set badlist ""
    		set empty ""
    		set hosp ""
    		set fieldcomp ""
    		set all ALL
    		set blnTrcWrite "T"
    		
    		#getting arguments from parameter list
    		keylget args MSGID mh
    		keylget args CONTEXT ctx
    		keylget args ARGS.SEGID segid
    		keylget args ARGS.FIELDID fieldid
    		keylget args ARGS.FIELDCOMP fieldcomp
    		keylget args ARGS.GOODLIST goodlist
    		keylget args ARGS.BADLIST badlist
    		keylget args ARGS.HOSP hosp
    		keylget args ARGS.TOFILE blnTrcWrite
    		
    		echo "Checking Field Values For Routing..................."
    		echo "SEGID: $segid FIELDID: $fieldid GOODLIST: $goodlist BADLIST: $badlist HOSP: $hosp"
    		
    		#If not sms_ib_data, do nothing.
    		if {(![cequal $ctx sms_ib_data]) && (![cequal $ctx xlt_pre]) && (![cequal $ctx xlt_raw]) && (![cequal $ctx xlt_post]) } {
    			#echo "\n\n$module ERROR!! Called with invalid context!"
    			echo "\n\nERROR!! Called with invalid context!"
    			echo "Should be sms_ib_data, is $ctx."
    			echo "Continuing message, no action taken.\n\n"
    			return "{CONTINUE $mh}"
    		}
    		
    		set msgtext [msgget $mh]
    		
    		if {$hosp == $empty} {
    			set hosp ALL
    		}
    		
    		if {$blnTrcWrite == $empty} {
	    	  set blnTrcWrite "T"
	      }
    		
    		#get the hosp from the msh segment
    		set mshseg [getHL7Segment $msgtext MSH]
    		set msghosp [getHL7Comp $mshseg 3 1]
    		set cid [getHL7Comp $mshseg 9 1]
    		
    		#get the message value to validate
    		if {$fieldcomp == $empty} {
    			set fieldcomp 1
    		}
    		
    		set seg [getHL7Segment $msgtext $segid]
    		set fieldinfo [getHL7Comp $seg $fieldid $fieldcomp]
    		set fieldinfo [string trim $fieldinfo]
    		set len [string length $fieldinfo]
    		set origfieldval $fieldinfo
    		
    		# Accucare wants the message killed if len is 0
    		#echo $len
    		set infofound [string first $fieldinfo $goodlist]
    		set infofound2 [string first $fieldinfo $badlist]
    		
    		# set up the reason for kill
	      set reason "$segid $fieldid is $fieldinfo and goodlist is $goodlist - badlist is $badlist"
    		
    		if {($infofound < 0) && ($goodlist != $empty) && (($hosp == $msghosp) || ($hosp == $all))} {
    			echo "Message Killed.  Message not sent to system...."
    			if { $blnTrcWrite == "T" } {
			       echo "Message Killed.  Message not sent to system....CID: $cid"
             set Zero [WriteKilledMsgToTracefile $msghosp $mh $reason]
			    } else {
			       echo "Message not written to tracefile...  CID: $cid Reason: $reason"
			    }
			  #  set dbResult [WriteKilledMsgToDatabase $mh $reason]
    			return "{KILL $mh}"
    		}
    		if {($infofound2 >= 0) && ($badlist != $empty) && (($hosp == $msghosp) || ($hosp == $all))} {
    			if { $blnTrcWrite == "T" } {
			       echo "Message Killed.  Message not sent to system...CID: $cid"
			       set Zero [WriteKilledMsgToTracefile $msghosp $mh $reason]
			    } else {
			       echo "Message not written to tracefile...  CID: $cid Reason: $reason"
			    }
			  #  set dbResult [WriteKilledMsgToDatabase $mh $reason]
    			return "{KILL $mh}"
    		}
    		return "{CONTINUE $mh}"
    	}
    	
    	shutdown {}
    	
    	default {
    		error "Unknown mode '$mode' in $module"
    		return ""
    	}
    }
}