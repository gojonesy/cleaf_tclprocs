proc test_decode_pdf { args } {
    package require base64
    global HciRoot HciConnName
    keylget args MODE mode
    set module "test_decode_pdf"
    set dispList {}
 
    switch -exact -- $mode {
        start {}
 
        run {
            keylget args MSGID mh
            set msg [msgget $mh]
 
            # Get the encoded PDF from the message
            set segs [split $msg \r]
            #set obx [lsearch -inline -all $segs OBX*]
            #set pdf [lindex [split [lindex $obx 1] |] 5]
            set obx [lsearch -inline $segs OBX*]
            set pdf [lindex [split $obx |] 5]
 
            # Create a unique filename for the output
            set midList [msgmetaget $mh MID]
            keylget midList NUM msgId
            set dateTime [clock format [clock seconds] -format %Y%m%d%H%M%S]
            set fileName "test-$dateTime-$msgId.pdf"
 
            # Base64 decode the PDF
            set fh [open $fileName w] ;# In the process directory
            fconfigure $fh -translation binary
            puts $fh [base64::decode $pdf]
            close $fh
 
            set dispList "{CONTINUE $mh}"
        }
 
        shutdown {}
        time {}
        default {}
    }
    return $dispList
}