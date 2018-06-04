#######################################################################################
# Name:		tps_KillMsgIfFldNotBlk
# Author:	Mark McGrath
# Date:	 	11/11/10   
# Purpose:	Kills message if a field is not blank
# UPoC type:	sms_ib_data or xlt_pre or xlt_raw
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#		segid - the name of the segment within which data resides
#		fieldid - the number of the field associated with the data
#		fieldcomp - the component number within the field - default
#			to first subcomponent
#
#  Updated:     
# 
#########################################################################################
proc tps_KillMsgIfFldNotBlk { args } {

    keylget args MODE mode              	

    set dispList {}

    switch -exact -- $mode {
  	start {
	    return ""	
    }

    run {

      #setting variables
      set empty ""
      set hosp ""
      set fieldcomp ""
      set all ALL
      set ldelimiter "`"
      set blnTrcWrite "T"
      set msgType ""
              
      #getting arguments from parameter list
      keylget args MSGID mh	
      keylget args CONTEXT ctx	
      keylget args ARGS.SEGID segid
      keylget args ARGS.FIELDID fieldid
      keylget args ARGS.FIELDCOMP fieldcomp
      keylget args ARGS.HOSP hosp
      keylget args ARGS.TOFILE blnTrcWrite

      #If not sms_ib_data, do nothing.
      if {(![cequal $ctx sms_ib_data]) && (![cequal $ctx xlt_pre]) && (![cequal $ctx xlt_raw])} {
	     echo "\n\n$module ERROR!! Called with invalid context!"
	     echo "Should be sms_ib_data, is $ctx."
	     echo "Continuing message, no action taken.\n\n"
	     return "{CONTINUE $mh}"
      }

      # Get rid of nulls in the message
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
	    
      # Added following line to remove hospital number identifier (Meditech problem)
      set msghosp [string trim [string range $msghosp 0 3]]
	    
      set cid [getHL7Comp $mshseg 9 1]

      #get the message value to validate
      if {$fieldcomp == $empty} {
        set fieldcomp 1
      }
	    
      # set up the reason for kill
      set reason "$segid  $fieldid  $fieldcomp must be blank."
  
      set seg [getHL7Segment $msgtext $segid]
  
      if {($seg == "")} {
	   		echo "Message Killed.  $reason  \nMessage not sent to system....CID: $cid"
	   		return "{KILL $mh}"
      }     
      set fieldinfo [getHL7Comp $seg $fieldid $fieldcomp]
      set fieldinfo [string trim $fieldinfo]
      set len [string length $fieldinfo]
      set origfieldval $fieldinfo
      
      if {($len > 0) && (($hosp == $msghosp) || ($hosp == $all))} {
				echo "Message Killed.  $reason  \nMessage not sent to system....CID: $cid"
				
				if { $blnTrcWrite == "T" } {
	    		set Zero [WriteKilledMsgToTracefile $msghosp $mh $reason]
				} else {
	    		echo "Message not written to tracefile...  CID: $cid"
				}
				return "{KILL $mh}"
      }
     return "{CONTINUE $mh}"	
    }
		
    shutdown {}
      default {
	      error "Unknown mode '$mode' in $module"
	      error "Unknown mode '$mode' in tps_KillMsgIfFldNotBlk.tcl"
	      return ""
      }
    }
 }
 