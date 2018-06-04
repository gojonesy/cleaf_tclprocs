


######################################################################
# Name:        
# Purpose:    <description>
# UPoC type:    xltp
# Args:        none
# Notes:    All data is presented through special variables.  The initial
#        upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#

proc xlt_get_first_field {} {
    upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals

        set inlist $xlateInVals
        set xlateOutVals [lindex $inlist 0]

}
