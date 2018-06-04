########################################################################
# Name:         isis_ftp.tcl   
# Purpose:      
#
# UPoC type: Called 
# Args: filename directory
#               
# Returns: flag (file found = 1, file not found = 0)
#
# Written by Mike Keys, January 18, 2016
# version 1.0
#
# This proc performs FTP operation from the Cloverleaf File Mover Server
# to the Clvoerleaf engine.
#########################################################################
proc isis_ftp {filename directory} {

    #Initialize Variables
    set isis_file $filename
    set dir $directory
    set smat_dir "/hci/cis6.1/integrator/ord_prod/exec/processes/CARD"
    set script_dir "ISIS_Scripts"
    set get_flag 0
    set put_flag 0
        
    # Initialize FTP file actions
    set getcmd "get \"$isis_file\""
    set rencmd "rename \"$isis_file\" transferred/\"$isis_file\""

    # Initialize FTP command files
    exec cp /home/hci/kshlib/$script_dir/isis_pdf_get_shell /home/hci/kshlib/$script_dir/isis_pdf_get
    #exec cp /home/hci/kshlib/$script_dir/isis_pdf_put_shell /home/hci/kshlib/$script_dir/isis_pdf_put

    
    #Set message handles to hold the above commands
    #set getfilemh [msgcreate -recover $getcmd]
    #set renamefilemh [msgcreate -recover $rencmd]
    
    #Modify the FTP command file for get command + filename
    set fh_get [open /home/hci/kshlib/$script_dir/isis_pdf_get a+]
    #msgwrite nl $getfilemh $fh_get
    puts $fh_get $getcmd
    #msgwrite nl $renamefilemh $fh_get
    puts $fh_get $rencmd
    close $fh_get

    #Modify the FTP command file for get command + filename
    #set fh_put [open /home/hci/kshlib/$script_dir/isis_pdf_put a+]
    #msgwrite nl $renamefilemh $fh_put
    #close $fh_put

    #Change to directory where transferred file will live
    cd $dir
    
    #Now we execute the FTP script
    set get_flag [catch { exec /home/hci/kshlib/$script_dir/isis_pdf_get_ftp.ksh } msg]
    #if [expr $get_flag == 1] {
        #set put_flag [catch { exec /home/hci/kshlib/$script_dir/isis_pdf_put_ftp.ksh } msg]
    #}
# This is the output
    cd $smat_dir
return $get_flag
}
