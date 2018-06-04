########################################################################
# Name:         pentax_ftp.tcl   
# Purpose:      This procedure sets up the commands/filenames needed 
#               as input into the individual *.ksh scripts that are 
#               used for the actual FTP process. 
# UPoC type: Called 
# Args: pentax_filename cdi_filename pdf_directory
#               
# Returns: integer
#          file found and transferred = 1
#          get pentax pdf file failed = 2
#          put cdi pdf file failed = 3
#
# Written by:
# Mike Keys
# June 14, 2016
# Version 1.0
#########################################################################
proc pentax_ftp {pentax_filename cdi_filename} {

    #Initialize Variables
    set pentax_file $pentax_filename
    set cdi_file $cdi_filename
    set pdf_dir "/home/hci/batch/PENTAX_PDF"
    set smat_dir "/hci/cis6.1/integrator/docu_prod/exec/processes/ENDO"
    set script_dir "PENTAX_Scripts"
    set get_flag 0
    set put_flag 0

    # Initialize FTP file actions
    set getcmd "get \"$pentax_file\""
    set putcmd "put \"$cdi_file\""
    

    # Initialize FTP command files
    exec cp /home/hci/kshlib/$script_dir/pentax_pdf_get_shell /home/hci/kshlib/$script_dir/pentax_pdf_get
    exec cp /home/hci/kshlib/$script_dir/pentax_pdf_put_shell /home/hci/kshlib/$script_dir/pentax_pdf_put


    #Set message handles to hold the above commands
    #set getfilemh [msgcreate -recover $getcmd]
    #set putfilemh [msgcreate -recover $putcmd]

    #Modify the FTP command file for get command + filename
    set mh_get [msgcreate -recover $getcmd]
    set fh_get [open /home/hci/kshlib/$script_dir/pentax_pdf_get a+]
    #puts $fh_get $getcmd
    msgwrite nl $mh_get $fh_get
    close $fh_get

    #Modify the FTP command file for put command + filename
    set mh_put [msgcreate -recover $putcmd]
    set fh_put [open /home/hci/kshlib/$script_dir/pentax_pdf_put a+]
    #puts $fh_put $putcmd
    msgwrite nl $mh_put $fh_put
    close $fh_put

    #Now we execute the FTP script
    set get_flag [catch {exec /home/hci/kshlib/$script_dir/pentax_pdf_get_ftp.ksh} msg]
    if [expr $get_flag == 1] {
        #Change to directory where transferred file will live and rename file
        #cd $pdf_dir
        exec cp /home/hci/batch/PENTAX_PDF/$pentax_file /home/hci/batch/PENTAX_PDF/$cdi_file
        exec rm /home/hci/batch/PENTAX_PDF/$pentax_file
        #exec mv $pentax_file $cdi_file
        #cd $smat_dir
        set put_flag [catch {exec /home/hci/kshlib/$script_dir/pentax_pdf_put_ftp.ksh} msg]
        if [expr $put_flag == 1] {
            return $put_flag
        } else {
            return 3
        }
    } else {
        return 2
    }
}
