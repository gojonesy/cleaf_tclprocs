############################################################################
# Name:   tps_KillMsgIfTableMatch
#
# # Purpose:    compare segment.field value to cloverleaf table entries 
#   					and kill/continue the message if value is found in the table
#
# Author:   Hope.Schnelten
# 					Justin Jones
#
# UPoC type:  tps
#
# Args:     tps keyedlist containing the following keys:
#           MODE     run mode ("start", "run" or "time")
#           MSGID    message handle  (no need to explicitly pass)
#           SEGFIELD Required. segment, field and component separated by a period.
#            (ex: PV1.3)
#           TABLE    Required.  The name of the table to compare. 
#							ex: table_name.tbl
#						ACTION	 CONTINUE or KILL.
#						TOFILE   T or F  (T=write to file, F=do not write. Default is T)
#
# example: {SEGFIELD {PV1.3.0}} {TABLE {table_name.tbl}} {ACTION CONTINUE} {TOFILE T}
#            NOTE: component is zero based index
#						 NOTE: IMPORTANT - The code is expecting a boolean value from the table.
#									 Therefore, it is important to add a default value to your table when you build it in cloverleaf. Make the default value 0, 
#									 and make the value for a match a 1				
# Returns:  tps disposition list
#
# Updates:  20150225 Mark McGrath --  Updated final KILL path messages to use
#           the reason set in the code before --  so no functionality change
#           just the final sent out reason
#
#           20161116 Mark McGrath  --  Updated to allow table to have values other than 1 and 0
#                                      Default values should still be 0 or NONE... if you need something else this will need updated
# 
################################################################################

proc tps_KillMsgIfTableMatch { args } {
   keylget args MODE mode                ;# Fetch mode
   set dispList {}     ;# Nothing to return
   set segArg ""
   set fieldArg ""
   set componentArg ""
   set tableArg ""
   set actionArg ""
   set fileWriteArg T
   keylget args MODE mode                ;# Fetch mode

   switch -exact -- $mode {
      start {
         # Perform special init functions
         # N.B.: there may or may not be a MSGID key in args
      }

      run {
         # initialize variables (run mode always has a MSGID; fetch and process it)
         keylget args MSGID mh
         keylget args ARGS.SEGFIELD segFieldArg
         keylget args ARGS.TABLE tableArg
         keylget args ARGS.ACTION actionArg
         keylget args ARGS.TOFILE fileWriteArg
         
         # convert the actionArg toupper
         set actionArg [string toupper $actionArg]
				 
         #get the message
         set msg [msgget $mh]

         #split the message into segments
         set seglist [split $msg \r]
         set segArg [lindex [split $segFieldArg .] 0] 
         set fieldArg [lindex [split $segFieldArg .] 1]
         set compArg [lindex [split $segFieldArg .] 2]
         set compareVal 0
				 set fieldVal ""
         # check for required arguments.  If any missing, set the message to be sent.
         if {[string length $segArg] == 0 || [string length $fieldArg] == 0 || [string length $compArg] == 0 || [string length $tableArg] == 0 || [string length $actionArg] == 0 } {
            echo "Args Missing."
            set msgAction CONTINUE
         } else {
            #split the message into segments
            set seglist [split $msg \r]
						set msgAction KILL
						
            foreach segment $seglist {
               set fieldlist [split $segment |]
               set segid [lindex $fieldlist 0]
               if {$segid == $segArg} {
                  set fieldVal [lindex $fieldlist [expr $fieldArg]]
                  #echo $fieldVal
                  set componentVal [lindex [split $fieldVal ^] [expr $compArg]]
                  #echo "componentVal: $componentVal"
                  #compare value in segment.field with cloverleaf table
                  set compareVal [hcitbllookup $tableArg $componentVal]
                  #echo "CompareVal: $compareVal"
                  if {[string equal $compareVal 0] || [string equal $compareVal "NONE"]} {
                     set compareVal 0
                  } else {
                     set compareVal 1
                  }
						if {$compareVal} {
             	  	#value in table - Determine action
             	  	#echo "Here"
             	  	if {$actionArg == "KILL" } {
               			set msgAction KILL
               			set reason "Match found for $segFieldArg: $componentVal in table $tableArg. Filter action is $actionArg which means to block if match is found."
    								} else {
    									set msgAction CONTINUE
    									set reason "Match found for $segFieldArg: $componentVal in table $tableArg. Filter action is $actionArg which means to send if match is found." 
										}       									     
            		} else {
            				if {$actionArg == "CONTINUE" } {
            					set msgAction KILL
            					set reason "No match for $segFieldArg: $componentVal in table $tableArg. Filter action is $actionArg which means to block if no match is found."
            				} else {
            					set msgAction CONTINUE
            					set reason "No match for 	$segFieldArg: $componentVal in table $tableArg. Filter action is $actionArg which means to send if no match is found."
            				}         				
            		} 
              		break
               }  
       
            }           
         } 

         if {$msgAction == "KILL"} {
            # changed to use the reason set from above.  Mark McGrath 02252015
            #echo "\n tps_KillMsgIfTableMatch.tcl ==> a match for $segArg $fieldArg $compArg value $fieldVal was found in table $tableArg; message killed  \n"
            #set reason "\n tps_KillMsgIfTableMatch.tcl ==> a match for $segArg $fieldArg $compArg value $fieldVal was found in table $tableArg; message killed  \n"
            echo "\n tps_KillMsgIfTableMatch.tcl ==> $reason  ; message killed  \n"
            set reason "\n tps_KillMsgIfTableMatch.tcl ==> $reason  ; message killed  \n"
            set mshseg [getHL7Segment $msg MSH]
            set cid [getHL7Comp $mshseg 9 1]
  
         if {$fileWriteArg == "F"} {
            echo "Message killed but not written to tracefile.  CID: $cid"
            #If no user arg passed in, will assume T (write to tracefile)
         } else {
            #get the hosp from message
            set msghosp [getHL7Comp $mshseg 2 1]
            set msghosp [string trim $msghosp]
            set spaceLoc [string first " " $msghosp]
            if {$spaceLoc > 0} {
               set msghosp [string trim [string range $msghosp 0 $spaceLoc]]
            }
            set Zero [WriteKilledMsgToTracefile $msghosp $mh $reason]
            }
         }
         lappend dispList "$msgAction $mh" 

      } 

      time {
            # Timer-based processing
      # N.B.: there may or may not be a MSGID key in args
      }
        
      shutdown {
        # Doing some clean-up work 
      }
   } 

   return $dispList
}
