######################################################################
# Name:		remove_cpt4_orc3
# Purpose:		Remove CPT4 code from ORC-3
#		
# Setup		11/26/2014
#		Michelle Nevill
#		
# UPoC type:	tps
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#       	ARGS    user-supplied arguments:
#               	<describe user-supplied args here>
#
# Returns: tps disposition list:
#          Will always continue message
#######################################################################

proc remove_cpt4_orc3 { args } {
    keylget args MODE mode              	;# Fetch mode

    set dispList {}				;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
	    # N.B.: there may or may not be a MSGID key in args
        }

        run {
    # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set msg [msgget $mh]
            set splitMsg [split $msg \r]
	  set space " "
	  set newmsg ""
	  set cr \r	
	  set last_seg ""
	  set nada ""


            foreach seg $splitMsg {

	       if {$seg == ""} {continue}

	       set fieldlist [split $seg |]
                 set segId [lindex $fieldlist 0]
#echo "segid = $segId"

	      switch -exact -- $segId {
	       
		ORC {

		set last_seg "ORC"
		set extra_flag "N"
		set orc3 [lindex $fieldlist 3]
#echo orc3 $orc3
		if { $orc3 != "" } {
		set neworc3 ""
#echo neworc3 $neworc3

	          set fieldlist [lreplace $fieldlist 3 3 $neworc3]
#echo fieldlist $fieldlist
		}
		set newseg [join $fieldlist |]
		lappend newmsg $newseg

		}

	       	default {
		  lappend newmsg $seg
	       }

                }  ;#end of switch
	   }  ;#end of foreach


	   set goodmsg [join $newmsg $cr]
	   msgset $mh $goodmsg
#echo goodmsg $goodmsg
	   lappend dispList "CONTINUE $mh"
	  	
	} ;#end run 

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
