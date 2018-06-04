###################################################################################
# Name:        filter_pttype_ptloc_ptserv_midas_4
# Purpose:              Routes the message if patient type in "I", "E", "N"
###################################################################################
# Setup:10/07/2008
#
# UPoC type:    tps - to be used in the inbound tps or the routing
# Args:     ARGS    user-supplied arguments:
#           Ex. {types {IN N OPB OP ER}}
# Returns: tps disposition list:
#          <describe dispositions used here>
###################################################################################

proc filter_pttype_ptloc_ptserv_midas_4 { args } {
    keylget args MODE mode                  ;# Fetch mode

    set dispList {}                ;# Nothing to return

    switch -exact -- $mode {
        start {
             # Perform special init functions
             # N.B.: there may or may not be a MSGID key in args
        }

        run {
             # 'run' mode always has a MSGID; fetch and process it
             # keylget args MSGID mh
             # get the arguments
                 keylget args ARGS.types types
              #echo $types
              set mh [keylget args MSGID]
              set dispList [list "CONTINUE $mh"]
              set msg [msgget $mh]
     
              set ptclassflag "N"  ;#  Declare and set vaiables
              set pttypeflag "N"
              set locflag "N"
              set killflag "N"
  
              set fldSep [string index $msg 3]  ;#  Field seperator.
              set subSep [string index $msg 4]  ;#  Sub-Field seperator.
              set segList [split $msg \r]       ;#  Create segment list using carriage return.
        
              set PV1 [lindex [lregexp $segList {^PV1}] 0]  ;#  Find PV-1 segment.
              set PV1flds [split $PV1 $fldSep]  ;#  Split PV-1 segment up into fields.
              set pttype [lindex $PV1flds 18]   ;#  Set variables to desired fileds.
#echo pttype $pttype
              set ptlocationflds [lindex $PV1flds 3]
                    set ptlocationsub [split $ptlocationflds $subSep]  ;#  Split field 3 into subfileds.
                    set ptlocation [lindex $ptlocationsub 0]  ;#  set variable to desired sub-filed.

              #Check to see if patient class inpatient, newborn, emergency, SDOP
                     
                     if {[lcontain $types $pttype]} {
                        set killflag "N"
                       
                       } else {
                           set killflag "Y"
                         } ;#end if
                       
                   echo type $pttype
                   echo $killflag
                   echo location $ptlocation

              #Check to see if patient location is in midas_locations.tbl
              #go through the midas_locations table and see if it finds a match

              set locflag [tbllookup -side input midas_locations.tbl $ptlocation]
 
              # Check to see if Pt Locations is "N" and Pt type is "CL".

                     if {[string equal $locflag "N"] && [string equal $pttype "CL"]} {
                           set killflag "Y"
                        #echo Loc $locflag
                                     #echo type$pttype
                         } else {
                          #set killflag "N"
                           } ;#
        
                   #echo $killflag
               # continue or kill the message

                     #echo "Kill: $killflag"
                     #echo "loc_flag $locflag"

                     if { $killflag == "Y" } {
                     set dispList [list "KILL $mh"]
                     return $dispList
           
                        } else {
                           return $dispList
                        } ;#end if

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
