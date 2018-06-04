######################################################################
# Name:        pk_check_msh3
# Purpose:        Checks MSH-3 for Vitals vs IO 
#                    
# Setup        09/21/2009
#        Michelle Nevill
# UPoC type:    tps
# Args:     tps keyedlist containing the following keys:
#           MODE    run mode ("start", "run" or "time")
#           MSGID   message handle
#           ARGS    user-supplied arguments:
#                   <describe user-supplied args here>
#
# Returns: tps disposition list:
#          <describe dispositions used here>
#########################################################################

proc pk_check_msh3 { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
        # N.B.: there may or may not be a MSGID key in args
        }

        run {
        # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh

        set msg [msgget $mh]
        set splitmsg [split $msg \r]
        
        foreach element $splitmsg {
           set splitfield [split $element |]
           set segid [lindex $splitfield 0]

            if { [cequal $segid MSH]} {
               set msh3 [lindex $splitfield 2]
    echo "msh = $splitfield"
    echo "MSH-3 = $msh3"
                if { $msh3 == "VITALS" } {
                set rindx [lsearch -regexp $splitfield "R01"]
    echo "rindx = $rindx"
                set newmsh [lreplace $splitfield $rindx $rindx "ORU^R03"]
    echo "newmsh = $newmsh"
                set newmsh2 [join $newmsh |]
    echo "newmsh2 = $newmsh2"
                lappend newmsg $newmsh2
                 } else {
                      lappend newmsg $element
                }
            } else {
               lappend newmsg $element
            }
        }    
       set goodmsg [join $newmsg \r]
       msgset $mh $goodmsg
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
