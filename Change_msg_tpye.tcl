######################################################################
# Name:		Change_msg_tpye
# Purpose:	Cahnge the message type
# UPoC type:	tps
# Args: 	tps keyedlist containing the following keys:
#       	MODE    run mode ("start", "run" or "time")
#       	MSGID   message handle
#       	ARGS    user-supplied arguments:
#               EX:{new_type {DFT^P03}}
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#

proc Change_msg_tpye { args } {
    keylget args MODE mode              	;# Fetch mode

    set dispList {}				;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
	    # N.B.: there may or may not be a MSGID key in args
        }

        run {
	    # 'run' mode always has a MSGID; fetch and process it
            #keylget args MSGID mh
            
            set mh [keylget args MSGID]
            keylget args ARGS.new_type NEW_TYPE
            #echo NEW_TYPE $NEW_TYPE
            set msg [msgget $mh]
            set Fld_Sep [string index $msg 3]  ;        #  Field Separator "|"
            set Com_Sep [string index $msg 4];          #  Component Separator "^"


            set segList [split $msg \r]       ;#  Create segment list using carriage return.
#echo segList $segList
	  set msh_loc [lsearch -regexp $segList {^MSH}]     ;#   Find MSH segment.
#echo msh_loc $msh_loc
            set MSH_Seg [lindex $segList $msh_loc]            ;# Set variable to list location.
	  set MSH_fields [split $MSH_Seg $Fld_Sep]          ;#  Split PID segment up into fields.
#echo MSH_fields $MSH_fields 
#echo hello
            set new_msh [lreplace $MSH_fields 8 8 $NEW_TYPE]
            set new_msh [join $new_msh $Fld_Sep]              ;# Put segments back together.
            set segList [lreplace $segList 0 0 $new_msh]      ;# Group the segment list back together.
            set new_Msg [join $segList \r]		;# put \r carriage return back into msg. 

            msgset $mh $new_Msg                               ;# Copy new msg over old msg to be sent out.

            lappend dispList "CONTINUE $mh"
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
