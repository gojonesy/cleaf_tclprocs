#######################################################################################
# Name:		tps_KillMsgByFldVal
# Author:	Barb Dozier
# Date:	 	9/1/03   
# Purpose:	Verifies the data within thE Message.  Kills those that are not wanted.
# UPoC type:	sms_ib_data or xlt_pre or xlt_raw
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
#
# Modified:     Mark McGrath   022604
#		Allow for the ability to scroll through a list of bad or good items
#		Uses the '`' as the list delimiter.  That way each item Can be compared as '='
#		instead of 'contained in'.  Added new function FindLists.
#
#               Mark McGrath   090606
#               Allow killed messages to be written to a trace file (KilledMsgs$HOSP)  
#               Easy retrieval/checking.  Calls trace file proc. (WriteKillMsgToTracefile)
#
#               Mark McGrath   101207
#               Remove all from space to end for Meditech
#
#########################################################################################
proc tps_KillMsgByFldVal { args } {

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
        set ldelimiter "`"
        set blnTrcWrite "T"
        set module "Context"
        
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

        #echo "Checking Field Values For Routing..................."
        #echo "SEGID: $segid FIELDID: $fieldid FIELDCOMP: $fieldcomp GOODLIST: $goodlist BADLIST: $badlist HOSP: $hosp"

        #If not sms_ib_data, do nothing.
	      if {(![string equal $ctx sms_ib_data]) && (![string equal $ctx xlt_pre]) && (![string equal $ctx xlt_raw]) && (![string equal $ctx xlt_post]) && (![string equal $ctx sms_ob_data])} {
		        #echo "\n\n$module ERROR!! Called with invalid context!"
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

	      #get the hosp from the msh segment
	      set mshseg [getHL7Segment $msgtext MSH]
	      set cid [getHL7Comp $mshseg 9 1]

	      # Only get the hosp from the message if hosp Arg is 'ALL' otherwise set msghosp = hosp
	      if {[string equal $hosp "ALL"] == 1} {
	          # Only take information up to space so killed file ends in Hosp Name
	          set msghosp [getHL7Comp $mshseg 3 1]
	          set msghosp [string trim $msghosp]
	          set spaceLoc [string first " " $msghosp]
	          if { $spaceLoc > 0 } {
	    	        set msghosp [string trim [string range $msghosp 0 $spaceLoc]]
	          }
	      } else {
	    	    set msghosp $hosp
	      }

	      #echo "meghosp $msghosp"

	      #get the message value to validate
	      if {$fieldcomp == $empty} {
	    	    set fieldcomp 1
	      }
	      set seg [getHL7Segment $msgtext $segid]
	      set fieldinfo [getHL7Comp $seg $fieldid $fieldcomp]
	      set fieldinfo [string trim $fieldinfo]
	      #echo "tps_KillMsgByFldVal fieldinfo: $fieldinfo"
	      set len [string length $fieldinfo]
	      set origfieldval $fieldinfo

        # NOTE: The if statement below allows a blank field to be processed.  
        # A blank field will not be killed.
	      if {$len > 0} {
	          set gList [split $goodlist $ldelimiter]
	          set bList [split $badlist $ldelimiter]
	         # echo "goodlist: $gList   badlist:  $bList"
	          set infofound [FindLists $gList $fieldinfo]
	          set infofound2 [FindLists $bList $fieldinfo]
	    
	          # set up the reason for kill
	          set reason "$segid $fieldid is $fieldinfo and goodlist is $goodlist - badlist is $badlist"
	          
	          # if field value not found (-1) then kill message
		        if {($infofound < 0) && ($goodlist != $empty) && (($hosp == $msghosp) || ($hosp == $all))} {
			          if { $blnTrcWrite == "T" } {
			              echo "Message Killed by tps_KillMsgByFldVal.  Message not sent to system....CID: $cid"
                    set Zero [WriteKilledMsgToTracefile $msghosp $mh $reason]
			          } else {
			              echo "Message not written to tracefile...  CID: $cid Reason: $reason"
			          }
			          return "{KILL $mh}"
		        }
		        if {($infofound2 >= 0) && ($badlist != $empty) && (($hosp == $msghosp) || ($hosp == $all))} {
			          
			          if { $blnTrcWrite == "T" } {
			              echo "Message Killed by tps_KillMsgByFldVal.  Message not sent to system...CID: $cid"
			              set Zero [WriteKilledMsgToTracefile $msghosp $mh $reason]
			          } else {
			              echo "Message not written to tracefile...  CID: $cid Reason: $reason"
			          }
			          return "{KILL $mh}"
		        }
	      }
	      return "{CONTINUE $mh}"	
    }

    shutdown {}

    default {
	      error "Unknown mode '$mode' in $module"
	      error "Unknown mode '$mode' in tps_KillMsgByFldVal.tcl"
	      return ""
    }
    }
}

###############################################################################
# Name:		FindLists
# Author:	Mark McGrath
# Date:	 	02/26/04
# Purpose:	Find sent value in list.
# Args: 	
#               SentList - list to search
#               ValueToFind - What to search for in the list
#
# Returns: Position of found item or -1
#
# Modified:     Mark McGrath   121113
#                updated non-List else to use string equal instead of string first
#
###############################################################################
proc FindLists { SentList ValueToFind } {
   set llen [llength $SentList]
   if { $llen > 1 } {
     set Located [lsearch $SentList $ValueToFind]
   } else {
     set Located [string first $ValueToFind [lindex $SentList 0]]
   }
   return $Located
}
