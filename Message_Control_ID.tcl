######################################################################
# Name:        Message_Control_ID
# Purpose:    This proc creates a unique identifer.
# UPoC type:    xltp
# Args:        system    <--- the system to add to the Control ID
#        counter    <--- a counter file name
#
#                    Put the args on the input side of the xlate for MSH10
#                    Ex.
#                       =PKTP      
#                       =counterFile    use descriptive name
#*******************************************************************************
#                Dont worry the counter resets at 10000
# Notes:    All data is presented through special variables.  The initial
#    upvar in this proc provides access to the required variables.
#
#        This proc style only works when called from a code fragment
#        within an XLT.
#
################################################################################

proc Message_Control_ID {} {
            global HciConnName        ;# Connection Name
            upvar xlateId       xlateId        \
      xlateInList   xlateInList    \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals    \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes    \
      xlateOutVals  xlateOutVals

      #Assign the arguments from the user to variables.
            lassign $xlateInVals system counter #debug

      # Check the current value of the counter
      set count [CtrCurrentValue $counter]
      
      # Check if the counter exists
      # if the counter does not exist create it.
      if {$count == 1} {
          CtrInitCounter $counter file 2 9999
      }

      # Get the value of the counter
      set count [CtrNextValue $counter]

      # Get a identifier from the getclock command
      set clock [getclock]

      # set the Control ID with the value of clock
      set control_id $clock

      # append the system name to the control id
      append control_id $system

      # append the counter value to the control id
      append control_id [format "%04s" $count]

            set xlateOutVals [lreplace $xlateOutVals 0 0 $control_id]

}
