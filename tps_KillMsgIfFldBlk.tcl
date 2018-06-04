#######################################################################################
# Name:		tps_KillMsgIfFldBlk
# Author:	Terry Ankrom
# Date:	 	10/10/06   
# Purpose:	Kills message if a field is blank
# UPoC type:	sms_ib_data or xlt_pre or xlt_raw
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#		segid - the name of the segment within which data resides
#		fieldid - the number of the field associated with the data
#		fieldcomp - the component number within the field - default
#			to first subcomponent
#
#  Updated:     MAM   070708
#               Added code to allow for removal of hospital numeric identifier from 
#               MSH 3 --  Meditech problem
#
#								JD 10-03-09
#								Option to not write to Tracefile was added as well as echo's to log file
#								to still have a record of what is being killed. MSH 9 message # and what
#						 		the reason is for killing.
#
#               CM 10-30-09
#               Added ability to pass message type as optional argument
# 
#########################################################################################
proc tps_KillMsgIfFldBlk { args } {

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
      keylget args ARGS.MSGTYPE msgType
      
      echo "SEGID: $segid FIELDID: $fieldid  FIELDCOMP: $fieldcomp MSGTYPE: $msgType"

      #If not sms_ib_data, do nothing.
	    if {(![cequal $ctx sms_ib_data]) && (![cequal $ctx xlt_pre]) && (![cequal $ctx xlt_post]) && (![cequal $ctx xlt_raw])} {
		     echo "\n\n KillMsgIfFldBlk ERROR!! Called with invalid context!"
		     echo "Should be sms_ib_data, is $ctx."
		     echo "Continuing message, no action taken.\n\n"
		     return "{CONTINUE $mh}"
	    }

      # Get rid of nulls in the message
      set msgtext [msgget -cvtnull "" $mh]

	    if {$hosp == $empty} {
	       set hosp ALL
	    }
	    
	    if {$blnTrcWrite == $empty} {
	       set blnTrcWrite "T"
	    }
	    
	    # set up the reason for kill
	    #set reason "$segid  $fieldid  $fieldcomp cannot be blank."

	    #get the hosp from the msh segment
	    set mshseg [getHL7Segment $msgtext MSH]
	    # echo "mshseg: $mshseg"
	    set msgt [getHL7Comp $mshseg 8 2]
	    # echo "type from msg: $msgt"
      # echo "type passed  : $msgType"
      
	    set msghosp [getHL7Comp $mshseg 3 1]
	    
	    # Added following line to remove hospital number identifier (Meditech problem)
	    set msghosp [string trim [string range $msghosp 0 3]]
	    
	    set cid [getHL7Comp $mshseg 9 1]

	    #get the message value to validate
	    if {$fieldcomp == $empty} {
	       set fieldcomp 1
	    	 #echo "this is fieldcomp $fieldcomp"
	    }
	    
	    # set up the reason for kill
	    set reason "$segid  $fieldid  $fieldcomp cannot be blank."
	    #echo $reason
	    set seg [getHL7Segment $msgtext $segid]
	    #echo "seg: $seg"
	    if {($seg == "") && ($msgType == "")} {
	       echo "Message Killed.  $segid $fieldid $fieldcomp cannot be blank.  \nMessage not sent to system....CID: $cid"
	       return "{KILL $mh}"
	    }     
	    set fieldinfo [getHL7Comp $seg $fieldid $fieldcomp]
	    #echo "fieldinfo -- $fieldinfo"
	    set fieldinfo [string trim $fieldinfo]
	    set len [string length $fieldinfo]
	    #echo "len -- $len"
	    #echo "hosp: $hosp --msghosp: $msghosp"
	    set origfieldval $fieldinfo
      
	    if {($len <= 0) && (($hosp == $msghosp) || ($hosp == $all)) && (($msgType == "") || ($msgt == $msgType))} {
		     echo "Message Killed.  $segid $fieldid $fieldcomp cannot be blank.  \nMessage not sent to system....CID: $cid"
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
	      error "Unknown mode '$mode' in tps_KillMsgIfFldBlk.tcl"
	      return ""
      }
    }
 }
 