######################################################################
# Name:         kill_msg.tcl
# Purpose:      Qualify on a field
# UPoC type:    tps
# Args:         tps keyedlist containing the following keys:
#               MODE    run mode ("start", "run" or "time")
#               MSGID   message handle
#               ARGS    user-supplied arguments:
#                       PASSCOND         Literal that is checked to continue msg
#                               if PASSCOND has a "~" in front of it consider it a not.
#                               if PASSCOND has "RANGE" as first 5 chars. it will look for a range of characters.
#                               if PASSCOND has "REGEX" as first 5 chars. it will look for a regular expression.
#                       SEGNAME         Segment to check
#                       FIELDNUM        Field number to check within the segment
#                       SUBFIELDNUM     Subfield to check within the field
#
# Args (Example ENTRY): To qualify on the patient location field (PV1 3) for OTC:
# the arguments would be:
# {PASSCOND <OTC>} {SEGNAME PV1} {FIELDNUM 3} {SUBFIELDNUM 0}
#
# Returns: tps disposition list:
#          $CONTINUE
#

proc kill_msg { args } {
    keylget args MODE mode                                      ;# Fetch mode

    set dispList {}                                             ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            keylget args MSGID mh
            set msg [msgget $mh]                                ;# Get message

#           
# Get arguments
#           
            set passcond {}
            keylget args ARGS.PASSCOND passcond                   ;# Fetch the pass literal
            set segname {} 
            keylget args ARGS.SEGNAME segname                   ;# Fetch the segment
            set fieldnum {}
            keylget args ARGS.FIELDNUM fieldnum                 ;# Fetch the fieldnum
            set subfieldnum {}
            keylget args ARGS.SUBFIELDNUM subfieldnum           ;# Fetch the subfieldnum

                        set subsubfieldnum -1
                        set check [string first "-" $subfieldnum]
                        if {![cequal $check "-1"]} {
                                incr check
                                set subsubfieldnum [crange $subfieldnum $check end]
                                incr check -2
                                set subfieldnum [crange $subfieldnum 0 $check]
                        }
                    #
                    # Split the message and get fields to check
                    # First set up some constants
                    #
            set sep [csubstr $msg 3 1]                          ;# HL7 field separator      
            set sub [csubstr $msg 4 1]                          ;# HL7 subfield separator           
                set subsub [csubstr $msg 7 1]                   ;# HL7 sub-subfield separator
            set segments [split $msg \r]                        ;# Get segments

                set segfound "N"

                    #
                    # LOOP through and make changes
                    #
            foreach seg $segments {
                if [cequal $seg ""] { continue }                ;# Just in case
                set segtype [csubstr $seg 0 3]                  ;# segment type
                if [cequal $segtype $segname] {                 ;# Segment?
                                set segfound "Y"
                    set fields [split $seg $sep]                ;# Fields
                    set checkfield [lindex $fields $fieldnum]   ;# field to check
                    set subfields [split $checkfield $sub]      ;# subfields
                    set checkvalue [lindex $subfields $subfieldnum]
                                if {![cequal $subsubfieldnum "-1"]} {
                                                set subsubfields [split $checkvalue $subsub]
                                                set checkvalue [lindex $subsubfields $subsubfieldnum]
                                }
                                if [cequal $passcond "EMPTY"] {
                                                set passcond ""
                                }
                                if [cequal [crange $passcond 0 0] "~"] {
                                                set passcond [crange $passcond 1 end]
                                                if [cequal $passcond "EMPTY"] {
                                                        set passcond ""
                                                }
                                                if [cequal [crange $passcond 0 4] "RANGE"] {
                                                        set passcond [crange $passcond 5 end]
                                                        if {[string match ${passcond}* $checkvalue]} {
                                                                lappend dispList "KILL $mh"
                                                                return $dispList
                                                        } else {
                                                                lappend dispList "CONTINUE $mh"
                                                                return $dispList
                                                        }
                                                } elseif {[cequal [crange $passcond 0 4] "REGEX"]} {
                                        
                                                        set passcond [crange $passcond 5 end]
                                                        if {[regexp ^$passcond$ $checkvalue]} {
                                                                lappend dispList "KILL $mh"
                                                                return $dispList
                                                        } else {
                                                                lappend dispList "CONTINUE $mh"
                                                                return $dispList
                                                        }
                                                } elseif {[cequal $checkvalue $passcond]} {
                                                        lappend dispList "KILL $mh"
                                                        return $dispList
                                                } else {
                                                        lappend dispList "CONTINUE $mh"
                                                        return $dispList
                                                }
                                } elseif {[cequal [crange $passcond 0 4] "RANGE"]} {
                                                set passcond [crange $passcond 5 end]
                                                if {[string match ${passcond}* $checkvalue]} {
                                                        lappend dispList "CONTINUE $mh"
                                                        return $dispList
                                                } else {
                                                        lappend dispList "KILL $mh"
                                                        return $dispList
                                                }
                                } elseif {[cequal [crange $passcond 0 4] "REGEX"]} {
                                                set passcond [crange $passcond 5 end]
                                                if {[regexp ^$passcond$ $checkvalue]} {
                                                        lappend dispList "CONTINUE $mh"
                                                        return $dispList
                                                } else {
                                                        lappend dispList "KILL $mh"
                                                        return $dispList
                                                }
                                } else {
                                if [cequal $checkvalue $passcond] {
                                        lappend dispList "CONTINUE $mh"
                                                        return $dispList
                        } else {
                                lappend dispList "KILL $mh"
                                                        return $dispList
                        }
                                }
                }
                        }              
        }

        time {
            # Timer-based processing
            # N.B.: there may or may not be a MSGID key in args
        }

                shutdown {
                # Doing some clean-up work
                }

        default {
            error "Unknown mode '$mode' in kill_msg"
        }
    }
    return $dispList
}

