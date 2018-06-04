##############################################################################
# Name:         filter_empty_PV1.tcl                                         #
# Purpose:      To filter out patient update messages with                   #
#               an ewmpty PV1 segment. This is due to the hnacombine         #
#               utility in Cerner and is caused by someone                   #
#               merging duplicate patient ID's with no encounters or         #
#               performing a historical updte to clean up old patient IDs.   #
# UPoC type:    TPS Inbound Data                                             #
# Args:         tps keyedlist containing the following keys:                 #
#               MODE    run mode ("start", "run" or "time")                  #
#               MSGID   message handle                                       #
#               ARGS    user-supplied arguments:                             #
#                                                                            #
# Returns: tps disposition list:                                             #
#          CONTINUE - Message was processed normally - continue into engine. #
#          KILL - Filter message from being processed.                       #
# Written by: Mike Keys, December 8th, 2016 @ 15:50                          #
##############################################################################
proc filter_empty_PV1 { args } {
    global HciConnName
    keylget args MODE mode         ;# Fetch mode
    keylget args CONTEXT context   ;# Fetch context
    set dispList {}                ;# Nothing to return
    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }
        run {
            keylget args MSGID mh               ;# Fetch the MSGID
            set msg [msgget $mh]                ;# Get the Message Handle
            set outbuf {}
            
            # Now we need to determine our field and sub components
            set field_sep [csubstr $msg 3 1]      ;# HL7 field separator
            set sub_sep [csubstr $msg 4 1]        ;# HL7 subfield separator
            set sub_sub_sep [csubstr $msg 7 1]      ;# HL7 sub-subfield separator
            set rep_sep [csubstr $msg 5 1]          ;# HL7 repeating separator
            set segmentList [split $msg \r]
            set msgDisp "CONTINUE"
            
            foreach segment $segmentList {
#MSH
                if [cequal [crange $segment 0 2] MSH] {                  
                    set fieldList [split $segment $field_sep]        
                    set msh_9 [lindex $fieldList 8]
                    set msh_9_1 [lindex [split $msh_9 $sub_sep] 1]
                    set segment [join $fieldList $field_sep]
                    append outbuf ${segment}\r              
#TXA
                } elseif [cequal [crange $segment 0 2] PV1] {      
                    set fieldList [split $segment $field_sep]        
                    set pv1_18 [lindex $fieldList 18]            
                    if [cequal $pv1_18 ""] {
                        if {[cequal $msh_9_1 "A08"] || [cequal $msh_9_1 "A34"]} {
                            set msgDisp "KILL"
                        }
                    }   
                    set segment [join $fieldList $field_sep]
                    append outbuf ${segment}\r                                                   
#OTHER                    
                } else {
                    append outbuf ${segment}\r
                }
            }            
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
            error "Unknown mode '$mode' in filter_empty_PV1"
        }
    }
    return $dispList
}
