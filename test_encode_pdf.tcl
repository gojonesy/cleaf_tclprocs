proc test_encode_pdf { args } {
    package require base64
    global HciRoot HciConnName
    keylget args MODE mode
    set module "test_encode_pdf"
    set dispList {}
 
    switch -exact -- $mode {
        start {}
 
        run {
            keylget args MSGID mh
            set msg [msgget $mh]
 
            # Encode the PDF file
            set fileName test_in.pdf ;# In the process directory
            set fh [open $fileName r]
            fconfigure $fh -translation binary
            set pdf [base64::encode [read $fh]]
            close $fh
 
            # Insert the encoded PDF into the message
            set segs [split $msg \r]
            set obxLoc [lsearch $segs OBX*]
            set obx [split [lindex $segs $obxLoc] |]
            set obx [join [lreplace $obx 5 5 $pdf] |]
            set segs [lreplace $segs $obxLoc $obxLoc $obx]
 
            msgset $mh [join $segs \r]
            set dispList "{CONTINUE $mh}"
        }
 
        shutdown {}
        time {}
        default {}
    }
    return $dispList
}
