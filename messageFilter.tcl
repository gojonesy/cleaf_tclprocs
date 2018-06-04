######################################################################
# Name:      messageFilter
# Purpose:   Will filter messages based on field values. Functionally filters based on multiple values
#            operating with OR logic conditioning. Can provide the optional "AND" condition arg to the 
#            proc to apply AND logic conditioning
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    {filter {MSH-8:ORU`PV1-3.3:MMC}} {action {KILL ANY}} {debug 1}
#
# Returns:   tps disposition list:
#            
# Notes:     filter is a tick (`) delimited list of Field/Value pairs. The field and value are delimted by a colon (:)
#            action is a list consiting of the disposition verb (KILL|CONTINUE) and the MODE (ALL|ANY)
#            Using ANY will perform the stated action if any of the fields meet the criteria. 
#            Using ALL will perform the stated action if ALL of the fields meet the criteria.
#
# History:   # History:   01/25/2017 Jones Created Proc.# History:   01/25/2017 Jones Created Proc.
#                 

proc messageFilter { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs debug debug}              ;# assume uargs is a keyed list

    set module "messageFilter" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
            }
        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            
            keylget args MSGID mh
            set msg [msgget $mh]; set segmentList [split $msg \r]
            # Sometimes the test messages have \r\n as the line endings.
            
            if { [llength $segmentList] < 2 } { 
                if {$debug} { puts "$module: The list is too small! Adjusting line endings." }
                set segmentList {}; set segmentList [split $msg \r\n]
            }
             # Setup parsing characters
            set fieldSep [string index $msg 3]; set subSep [string index $msg 4]
            set repeatSep [string index $msg 5]; set counter 0
            set actionFlag 0
            
            set filterList ""; set action ""
            keylget args ARGS.filter filterList; keylget args ARGS.action action
            
            if {$debug} { puts "$module: filterList: $filterList"; puts "$module: action: $action"}
            if {$debug } { puts "$module: Segment List: $segmentList" }
            set actionList [split $action " "]
            # The action list should be formatted as "ACTION MODE" where
            # Action is either KILL or CONTINUE and Mode is either
            # ALL or ANY
            if {[llength $actionList] < 2} { puts "Action list should be 2 valid items"; exit }
            if { [string toupper [lindex $actionList 0]] ni {KILL CONTINUE}} {
                puts "$module: Action doesn't match valid action (KILL|CONTINUE). Continuing message."
                lappend dispList "CONTINUE $mh"; return $dispList
            }
            if { [string toupper [lindex $actionList 1]] ni {ANY ALL}} {
                puts "$module: Mode doesn't match valid mode (ANY|ALL). Continuing message."
                lappend dispList "CONTINUE $mh"; return $dispList
            }

            
            # Split the filter into a list of field-value pairs (values can be a list)
            set filters [split $filterList `]
            foreach filter $filters {
                if {$debug} { puts "$module: filter: $filter" }
                # Split the filter on the colon. The first is the Field, the second value is the value.
                set field [lindex [split $filter :] 0]; set values [split [lindex [split $filter :] 1] " "]
                if {$debug} { puts "$module: Field: $field"; puts "$module: Values: $values" }
                # Split the field to find subcomponents, etc.
                set segment [lindex [split $field -] 0]
                set comp [lindex [split [lindex [split $field -] 1] .] 0]
                set subComp [lindex [split [lindex [split $field -] 1] .] 1]
                if { $subComp == "" } { set subComp 0 }
                if {$debug} { 
                    puts "$module: Segment: $segment"; puts "$module: Comp: $comp"
                    puts "$module: SubComp: $subComp" 
                }

                # We're now ready to locate the values.
                set segPos [lsearch -regexp $segmentList "^$segment"]
                puts "segPos: $segPos"
                set segFieldList [split [lindex $segmentList $segPos] $fieldSep]
                if {$debug} { puts "$module: Segment fields: $segFieldList" }

                if {$segment == [lindex $segFieldList 0]} {
                    # if {$debug} { puts "$module: $field Found!" }
                    # Split field into subcomponents
                    set subList [split [lindex $segFieldList $comp] $subSep]
                    if {$debug} { puts "$module: SubList: $subList" }
                    
                    # Match the values
                    if {[lindex $subList $subComp] eq "" } { 
                        set subList [lreplace $subList $subComp $subComp "BLANK"] 
                    }

                    foreach value $values {
                        if {[lindex $subList $subComp] == $value} {
                            if {$debug} { puts "$module: $value found in $field!" }
                            # Need to determine the action to take.
                            if { [string toupper [lindex $actionList 1]] == "ALL" } {
                                #puts "Value found, incrementing actionFlag"
                                incr actionFlag; continue
                            } else {
                                # Since the ANY mode was selected, we can perform the action without checking other
                                # values.
                                puts "$module: ANY condition met. [lindex $actionList 0]ing message."
                                puts "$module: $filter"
                                lappend dispList "[string toupper [lindex $actionList 0]] $mh"
                                return $dispList
                            }
                        
                        
                        }
                    }
                    
                }
            }

            # Check our ALL Flag. If it is equal to the number of filters specified, then perform action.
            puts "$module: actionFlag: $actionFlag, Filter length: [llength $filters]"
            if { $actionFlag == [llength $filters]} {
                # ALL Condition met. Peform Action
                puts "$module: ALL Condition met. [lindex $actionList 0]ing message."
                puts "$module: $filter"
                lappend dispList "[string toupper [lindex $actionList 0]] $mh"
                return $dispList
            } else {
                # The default is always to continue the message.
                # Was the action continue? If so, we need to kill the message.
                if { [string toupper [lindex $actionList 0]] == "KILL" } {
                    lappend dispList "CONTINUE $mh"
                } else {
                    lappend dispList "KILL $mh"
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
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}
