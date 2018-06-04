######################################################################
# Name:        xlt_dft_get_doctor_num
# Purpose:  <description>
# UPoC type:    xltp
# Args:     none
# Notes:    All data is presented through special variables.  The initial
#       upvar in this proc provides access to the required variables.
#
#       This proc style only works when called from a code fragment
#       within an XLT.
#

proc xlt_dft_get_doctor_num {} {
    upvar xlateId       xlateId     \
      xlateInList   xlateInList \
      xlateInTypes  xlateInTypes    \
      xlateInVals   xlateInVals \
      xlateOutList  xlateOutList    \
      xlateOutTypes xlateOutTypes   \
      xlateOutVals  xlateOutVals

echo xlateInVals $xlateInVals

set lastname [lindex $xlateInVals 0]
set firstname [lindex $xlateInVals 1]

echo "lname $lastname"
echo "fname $firstname"

package require odbc

# Set handles and driver version

              odbc SQLAllocHandle SQL_HANDLE_ENV SQL_NULL_HANDLE henv
              odbc SQLSetEnvAttr $henv SQL_ATTR_ODBC_VERSION SQL_OV_ODBC3 0
              odbc SQLAllocHandle SQL_HANDLE_DBC $henv hdbc
         
      set PERSID ""

      #connect to database
 
             set DB_connect [odbc SQLConnect $hdbc ORAPROD SQL_NTS v500 SQL_NTS in10sive2 SQL_NTS]
             set error [odbc SQLGetDiagRec SQL_HANDLE_DBC $hdbc 1 SqlState NativeError MessageText 711 TextLength]

            # echo MessageText $MessageText

            echo DB_connect $DB_connect

odbc SQLAllocHandle SQL_HANDLE_STMT $hdbc hstmt

            set select_one "select person_id from prsnl where name_last_key = '$lastname' and name_first_key = '$firstname'"

            set select_one_call [odbc SQLExecDirect $hstmt $select_one SQL_NTS]
            echo select_one_call $select_one_call

            set select_one_value [odbc SQLBindCol $hstmt 1 SQL_C_CHAR PERSID 64 Len]
            echo select_one_value $select_one_value

            set rVal [odbc SQLFetch $hstmt]
            echo rVal $rVal
            echo PERSID $PERSID

    if { $PERSID == "" } {
       set ALIAS "00000000"

    } else {

odbc SQLAllocHandle SQL_HANDLE_STMT $hdbc hstmt2

            set select_three "Select alias from prsnl_alias where person_id = '$PERSID' and alias_pool_cd = 678020 and active_ind = 1" 

            set select_three_call [odbc SQLExecDirect $hstmt2 $select_three SQL_NTS]
            echo select_three_call $select_three_call

            set select_three_value [odbc SQLBindCol $hstmt2 1 SQL_C_CHAR ALIAS 64 Len]
      echo select_three value $select_three_value

             set rVal2 [odbc SQLFetch $hstmt2]
            echo rVal2 $rVal2

      if { $rVal2 == "SQL_NO_DATA_FOUND" } {
         set ALIAS "97039"
      }
      echo ALIAS $ALIAS

            #set error2 [odbc SQLGetDiagRec SQL_HANDLE_STMT $hstmt2 1 SqlState NativeError MessageText2 711 TextLength]

            #echo MessageText2 $MessageText2

            odbc SQLFreeHandle SQL_HANDLE_STMT $hstmt2
         }

#  Return control to the engine.  And clean up handles
            
            odbc SQLFreeHandle SQL_HANDLE_STMT $hstmt
#            odbc SQLFreeHandle SQL_HANDLE_STMT $hstmt1
#            odbc SQLFreeHandle SQL_HANDLE_STMT $hstmt2
            odbc SQLDisconnect $hdbc
            odbc SQLFreeHandle SQL_HANDLE_DBC $hdbc
            odbc SQLFreeHandle SQL_HANDLE_ENV $henv

   set xlateOutVals [format "%0#8s" $ALIAS]

}
