######################################################################
# Name:      SC_RAD_OUT4
# Purpose:   <description>
# UPoC type: tps
# Args:      tps keyedlist containing the following keys:
#            MODE    run mode ("start", "run", "time" or "shutdown")
#            MSGID   message handle
#            CONTEXT tps caller context
#            ARGS    user-supplied arguments:
#                    <describe user-supplied args here>
#
# Returns:   tps disposition list:
#            <describe dispositions used here>
#
# Notes:     <put your notes here>
#
# History:   <date> <name> <comments>
#                 

proc SC_RAD_OUT4 { args } {
    global HciConnName                             ;# Name of thread
    
    keylget args MODE mode                         ;# Fetch mode
    set ctx ""   ; keylget args CONTEXT ctx        ;# Fetch tps caller context
    set uargs {} ; keylget args ARGS uargs         ;# Fetch user-supplied args

    set debug 0  ;                                 ;# Fetch user argument DEBUG and
    catch {keylget uargs DEBUG debug}              ;# assume uargs is a keyed list

    set module "SC_ORU_OUT4/$HciConnName/$ctx" ;# Use this before every echo/puts,
                                                   ;# it describes where the text came from

    set dispList {}                                ;# Nothing to return

    switch -exact -- $mode {
        start {
            # Perform special init functions
            # N.B.: there may or may not be a MSGID key in args
            
            if { $debug } {
                puts stdout "$module: Starting in debug mode..."
            }

            package require odbc  

      namespace eval scprod {

# Set handles and driver version and Connect to SQL database
  
              odbc SQLAllocHandle SQL_HANDLE_ENV SQL_NULL_HANDLE henv
              odbc SQLSetEnvAttr $henv SQL_ATTR_ODBC_VERSION SQL_OV_ODBC3 0
              odbc SQLAllocHandle SQL_HANDLE_DBC $henv hdbc 
              #set DB_connect [odbc SQLConnect $hdbc MMC-SQL-SCPROD SQL_NTS SCUser SQL_NTS s(Us3r09 SQL_NTS]
              set DB_connect [odbc SQLConnect $hdbc MMC-SQL-SCTEST SQL_NTS SCUser SQL_NTS s(Us3r09 SQL_NTS]
              echo DB_connect $DB_connect
              if {![string equal $DB_connect "SQL_SUCCESS_WITH_INFO"]} {
                   set CON_MessageText ""
                   set error [odbc SQLGetDiagRec SQL_HANDLE_DBC $hdbc 1 SqlState NativeError CON_MessageText 711 TextLength]
                   echo CON_MessageText $CON_MessageText
              }       

      }

        }

        run {
            # 'run' mode always has a MSGID; fetch and process it
            
             set mh [keylget args MSGID]     

       set level2 "0"
       set ordmd_flag "N"
       set sc_values "SQL_SUCCESS"
       set MMC_MRN ""
       set ORD_SITE ""
       set RAD_ORD_ID ""
       set MILLI_ORD_ID ""
       set TW_ORDER_ID ""
       set SC_MRN ""
       set SC_RAD_CODE ""
       set ORD_DOCTOR_ID ""
       set ORD_DOCTOR_NAME ""
       set ORDER_DT_TM ""
       set mps_ord_md "N"
       set s1count ""
       set s2count ""
       set matchflag "0"
       set resendflag "0"
       set twkeep ""
       set mrnkeep ""
       set scmrnkeep ""
       set labkeep ""
                       
              package require odbc

            #  Get the message that was passed to the engine.

              set msg [msgget $mh]
              set Fld_Sep [string index $msg 3]  ;        #  Field Separator "|"
              set Com_Sep [string index $msg 4]  ;        #  Component Separator "^"
#echo $msg
              set segList [split $msg \r]       ;#  Create segment list using carriage return.
            
        set MSH_Seg [lindex [lregexp $segList {^MSH}] 0]  ;#  Find MSH segment.
        set MSH_fields [split $MSH_Seg $Fld_Sep]          ;#  Split MSH segment up into fields.
            
              set tran_dt  [string range [lindex $MSH_fields 6] 0 7]
              set tran_tm  [string range [lindex $MSH_fields 6] 8 11]

              
              set pid_loc [lsearch -regexp $segList {^PID}]  ;#   Find PID segment.
              #echo pid_loc $pid_loc           
              set PID_Seg [lindex $segList $pid_loc]  ;#  Find PID segment.

        set PID_fields [split $PID_Seg $Fld_Sep]          ;#  Split PID segment up into fields.
        #echo PID_fields $PID_fields
    
              set mmc_mrn  [lindex $PID_fields 3]
        set mmc_mrn_sub [split $mmc_mrn $Com_Sep]
              set mmc_mrn  [lindex $mmc_mrn_sub 0]
              set mmc_mrn [string trimleft $mmc_mrn 0]
              echo mmc_mrn $mmc_mrn
              
              set name [lindex $PID_fields 5]
        set name_sub [split $name $Com_Sep]
        set lname [lindex $name_sub 0]
              set fname [lindex $name_sub 1]
              set mname [lindex $name_sub 2]
              #echo $lname $fname $mname
        set fnmatch [string range $fname 0 3]
        set fnmatch "$fnmatch%"
        #echo fnmatch $fnmatch

              set dob [string range [lindex $PID_fields 7] 0 9]
              #echo dob $dob
              
              set sex [lindex $PID_fields 8]
        set pid18 [lindex $PID_fields 18]
        set fin [lindex [split $pid18 ^] 0]
        set ssn [lindex $PID_fields 19]
               #echo ssn $ssn
              
              set obr_loc [lsearch -regexp $segList {^OBR}]  ; #Find OBR segment.

              set OBR_Seg [lindex $segList $obr_loc]

              set OBR_fields [split $OBR_Seg $Fld_Sep]

              set mmc_order_id [lindex $OBR_fields 2]
set mmc_order_id_sub [split $mmc_order_id $Com_Sep]
set mmc_order_id [lindex $mmc_order_id_sub 0]

              #echo mmc_order_id $mmc_order_id

              set mmc_order_code [lindex $OBR_fields 4]

              set mmc_order_code_sub [split $mmc_order_code $Com_Sep]
              echo mmc_order_code_sub $mmc_order_code_sub

              set mmc_order_code [lindex $mmc_order_code_sub 0]
              #echo mmc_order_code $mmc_order_code
              set mmc_order_desc [lindex $mmc_order_code_sub 1]
              #echo mmc_order_desc $mmc_order_desc

              set obr_dr_name [lindex $OBR_fields 16]
              set obr_dr_name [split $obr_dr_name ^]
              set obr_dr_npi [lindex $obr_dr_name 0]
              set ord_dr_npi [tbllookup -side input SC_Doctors_NPI_v6.tbl $obr_dr_npi]      
#echo ord_dr_npi $ord_dr_npi
              set obr_dr_Lname [lindex $obr_dr_name 1]
              set obr_dr_Fname [lindex $obr_dr_name 2]
              set space " "
              append  new_obr_dr_name $obr_dr_Lname,$space$obr_dr_Fname
              #echo new_obr_dr_name $new_obr_dr_name

              set mmc_rad_order_id [lindex $OBR_fields 20]

set mmc_rad_order_id_sub [split $mmc_rad_order_id $Com_Sep]
set mmc_rad_order_id [lindex $mmc_rad_order_id_sub 0]
#echo mmc_rad_order_id $mmc_rad_order_id  
         
              set obx_loc [lsearch -regexp $segList {^OBX}]   ; #Find OBX segment.

              set OBX_Seg [lindex $segList $obx_loc]

              set OBX_fields [split $OBX_Seg $Fld_Sep]
              #echo OBX_fields $OBX_fields
  
# Do table lookup for SC RAD Code that corresponds with MMC RAD Code to use in below matching criteria

              #set sc_rad_code [tbllookup -side input Rad_Codes_2_SC.tbl $mmc_order_code]
              #echo sc_rad_code_herel $sc_rad_code
#set RAD RAD
#echo RAD $RAD
#append newradcode $RAD $sc_rad_code
#set sc_rad_code $newradcode
#echo newradcode $newradcode
#echo radmess $sc_rad_code
set sc_rad_code ""

               if {[string equal $sc_rad_code " "]} {   
#echo here
                   set sc_rad_code $mmc_order_code
               }

              #set seperator_loc [string first $Com_Sep $sc_rad_code]
              set seperator_loc 0

              #echo seperator_loc $seperator_loc

              if {$seperator_loc > 0} {
                  set sc_rad_code_sub1 [string range $sc_rad_code 0 [expr {$seperator_loc-1}]]
                  #echo sc_rad_code_sub1 $sc_rad_code_sub1

              } else {
                       set sc_rad_code_sub1 $sc_rad_code
              }
 

# Declare statement handle for update

              odbc SQLAllocHandle SQL_HANDLE_STMT $scprod::hdbc hstmt


set select1 "SELECT COUNT(*) AS EXPR1 FROM TW_RADORDERS WHERE MRN='$mmc_mrn' AND ORD_DOCTOR_ID='$ord_dr_npi' AND SC_RAD_CODE='$mmc_order_code' AND DOB='$dob' AND LNAME='$lname' AND FNAME like '$fnmatch' AND ORDER_STATUS != 'CA'"

#echo select1 $select1

       set select1_call [odbc SQLExecDirect $hstmt $select1 SQL_NTS]
       echo select1_call $select1_call

             odbc SQLBindCol $hstmt 1 SQL_C_CHAR s1count 64 Len
             set s1_check [odbc SQLFetch $hstmt]

echo S1COUNT $s1count

             # Free up memory and disconnect from database

               odbc SQLFreeHandle SQL_HANDLE_STMT $hstmt


# Check to see if select was performed.

        if { $s1count >= 1 } {


    # Declare statement handle for select 
      
                odbc SQLAllocHandle SQL_HANDLE_STMT $scprod::hdbc hstmt1A


set select1A "SELECT TW_ORDER_ID, SC_RAD_CODE, SC_MRN, MRN, MILLI_ORDER_ID FROM TW_RADORDERS WHERE MRN='$mmc_mrn' AND ORD_DOCTOR_ID='$ord_dr_npi' AND SC_RAD_CODE='$mmc_order_code' AND DOB='$dob' AND LNAME='$lname' AND FNAME like '$fnmatch' AND ORDER_STATUS != 'CA' ORDER BY TW_ORDER_ID"
#echo select1A -- $select1A
           set select1A_info [odbc SQLExecDirect $hstmt1A $select1A SQL_NTS]
           echo select1A_info $select1A_info

# Bind values returned by select to columns.       

                        odbc SQLBindCol $hstmt1A 1 SQL_C_CHAR TW_ORDER_ID 64 Len
                        odbc SQLBindCol $hstmt1A 2 SQL_C_CHAR SC_RAD_CODE 64 Len
           odbc SQLBindCol $hstmt1A 3 SQL_C_CHAR SC_MRN 64 Len
           odbc SQLBindCol $hstmt1A 4 SQL_C_CHAR MMC_MRN 64 Len
           odbc SQLBindCol $hstmt1A 5 SQL_C_CHAR MILLI_ORD_ID 64 Len

                        set sc_values1A [odbc SQLFetch $hstmt1A]
                        #echo sc_values1A $sc_values1A
echo TW_ORDER_ID $TW_ORDER_ID
echo SC_RAD_CODE $SC_RAD_CODE
echo MILLI_ORD_ID $MILLI_ORD_ID
echo SC_MRN $SC_MRN
            while { $sc_values1A == "SQL_SUCCESS" } {
               if { $MILLI_ORD_ID == $mmc_order_id } {
                  set resendflag "1"
            set matchflag "1"
#echo resendflag $resendflag
            set twkeep $TW_ORDER_ID
            set mrnkeep $MMC_MRN
            set scmrnkeep $SC_MRN
                  set radkeep $SC_RAD_CODE
#echo twkeep $twkeep
#echo radkeep $radkeep
            break
               } elseif { $twkeep == "" && $MILLI_ORD_ID == "" } {
            set matchflag "1"
            set twkeep $TW_ORDER_ID
            set mrnkeep $MMC_MRN
            set scmrnkeep $SC_MRN
                  set radkeep $SC_RAD_CODE
#echo twkeep $twkeep
#echo radkeep $radkeep
               }
               set TW_ORDER_ID ""
               set SC_RAD_CODE ""
               set SC_MRN ""
               set MMC_MRN ""
               set MILLI_ORD_ID ""
                           set sc_values1A [odbc SQLFetch $hstmt1A]
                           #echo sc_values1A $sc_values1A
echo TW_ORDER_ID $TW_ORDER_ID
echo SC_RAD_CODE $SC_RAD_CODE
echo MILLI_ORD_ID $MILLI_ORD_ID
echo SC_MRN $SC_MRN
            }
                # Free up memory and disconnect from database

                odbc SQLFreeHandle SQL_HANDLE_STMT $hstmt1A


        # Declare statement handle for update

                odbc SQLAllocHandle SQL_HANDLE_STMT $scprod::hdbc hstmtUPD


        # Prepare and execute update statement.
set update1 "UPDATE TW_RADORDERS SET MILLI_ORDER_ID ='$mmc_order_id', RAD_ORDER_ID ='$mmc_rad_order_id', MMC_RAD_CODE ='$mmc_order_code', MMC_RAD_DESC = '$mmc_order_desc', FIN = '$fin' WHERE TW_ORDER_ID='$twkeep'"

#echo update1 $update1
                            set update1_call [odbc SQLExecDirect $hstmtUPD $update1 SQL_NTS]
                            echo update1_call $update1_call

# Check to see if update was performed.

                            if {![string equal $update1_call "SQL_SUCCESS"]} {
                        set IN_MessageText ""
                        odbc SQLGetDiagRec SQL_HANDLE_STMT $hstmtUPD 1 SqlState NativeError IN_MessageText 711 TextLength
                        echo IN_MessageText $IN_MessageText
                           }

             # Free up memory and disconnect from database

                       odbc SQLFreeHandle SQL_HANDLE_STMT $hstmtUPD


              } elseif { $s1count == "0" } {


    # Declare statement handle for select     
  
                odbc SQLAllocHandle SQL_HANDLE_STMT $scprod::hdbc hstmt2A

set select2A "SELECT TW_ORDER_ID, SC_RAD_CODE, SC_MRN, MRN, ORD_DOCTOR_ID, ORD_DOCTOR_NAME, FMT_ORDER_DT_TM FROM TW_RADORDERS WHERE MRN='$mmc_mrn' AND ORD_DOCTOR_ID != '$ord_dr_npi' AND SC_RAD_CODE='$mmc_order_code' AND DOB='$dob' AND LNAME='$lname' AND FNAME like '$fnmatch' AND ORDER_STATUS != 'CA' ORDER BY TW_ORDER_ID"
#echo select2A -- $select2A
           set select2A_info [odbc SQLExecDirect $hstmt2A $select2A SQL_NTS]
           echo select2A_info $select2A_info

# Bind values returned by select to columns.       

                        odbc SQLBindCol $hstmt2A 1 SQL_C_CHAR TW_ORDER_ID 64 Len
                        odbc SQLBindCol $hstmt2A 2 SQL_C_CHAR SC_RAD_CODE 64 Len
           odbc SQLBindCol $hstmt2A 3 SQL_C_CHAR SC_MRN 64 Len
           odbc SQLBindCol $hstmt2A 4 SQL_C_CHAR MMC_MRN 64 Len
           odbc SQLBindCol $hstmt2A 5 SQL_C_CHAR ORD_DOCTOR_ID 64 Len
           odbc SQLBindCol $hstmt2A 6 SQL_C_CHAR ORD_DOCTOR_NAME 64 Len
           odbc SQLBindCol $hstmt2A 7 SQL_C_CHAR ORDER_DT_TM 64 Len

                        set sc_values2A [odbc SQLFetch $hstmt2A]
                        #echo sc_values2A $sc_values2A
echo TW_ORDER_ID $TW_ORDER_ID
echo SC_RAD_CODE $SC_RAD_CODE
echo MILLI_ORD_ID $MILLI_ORD_ID
echo SC_MRN $SC_MRN
echo ORD_DOCTOR_ID $ORD_DOCTOR_ID
echo ORD_DOCTOR_NAME $ORD_DOCTOR_NAME
echo ORDER_DT_TM $ORDER_DT_TM

        if { $sc_values2A != "SQL_NO_DATA_FOUND" } {
#echo "ORDERING MD MISMATCH!!!"

                 set fh [open /home/hci/batch/SC_files/rad_sc_ord_md_errors a+]


            puts $fh ""
            puts $fh "        SC RAD ORDERING MD MISMATCH -- ORDER DATA\n"
            puts $fh "MMC Order No:                          $mmc_order_id"
            puts $fh "MMC Order Code:                        $mmc_order_code"  
            puts $fh "MMC Accession #:                       $mmc_rad_order_id"  
            puts $fh "MMC MRN:                               $mmc_mrn" 
            puts $fh "Patient Last Name:                     $lname"
            puts $fh "Patient First Name:                    $fname"
            puts $fh "Patient Middle Name:                   $mname"
            puts $fh "MMC Ordering DR.:                      $new_obr_dr_name"   
            puts $fh "MMC Ordering DR. NPI:                  $ord_dr_npi"      
            puts $fh "SC Ordering DR.:                       $ORD_DOCTOR_NAME"
            puts $fh "SC Ordering DR. NPI:                   $ORD_DOCTOR_ID"
            puts $fh "SC Order Date/Time:                    $ORDER_DT_TM"

            close $fh
      exec /home/hci/kshlib/rad_sc_ord_errs.ksh
        }

             # Free up memory and disconnect from database

               odbc SQLFreeHandle SQL_HANDLE_STMT $hstmt2A

       }

            
      if { $scmrnkeep != ""} {
                set newPid [lreplace $PID_fields 2 2 $scmrnkeep]
                set newPid [join $newPid $Fld_Sep]                                ;# Put segments back together.
                set segList [lreplace $segList $pid_loc $pid_loc $newPid]         ;# Place new PID segmnet in list.
      }


      if { $twkeep != "" } {
               set newOBR [lreplace $OBR_fields 2 2 $twkeep]                ;# Build new OBR.
               set newOBR [join $newOBR $Fld_Sep]
               set segList [lreplace $segList $obr_loc $obr_loc $newOBR]
      }


          #set newOBX [lreplace $OBX_fields 3 3 $SC_RAD_CODE]                              ;# Build new OBX
          #set newOBX [join $newOBX $Fld_Sep]
          #set segList [lreplace $segList $obx_loc $obx_loc $newOBX]

          set new_msg [join $segList \r]                                 ;# put \r carriage return back into msg. 
          #echo new_msg $new_msg
          
            msgset $mh $new_msg

            lappend dispList "CONTINUE $mh"
        }

        time {
            # Timer-based processing
            # N.B.: there may or may not be a MSGID key in args
            
        }
        
        shutdown {
            # Doing some clean-up work - Close SQL connection

            odbc SQLDisconnect $scprod::hdbc
            odbc SQLFreeHandle SQL_HANDLE_DBC $scprod::hdbc
            odbc SQLFreeHandle SQL_HANDLE_ENV $henv

            
        }
        
        default {
            error "Unknown mode '$mode' in $module"
        }
    }

    return $dispList
}
