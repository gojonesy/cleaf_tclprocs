set rootdir $env(HCIROOT); set site "adt_test"

if {[catch {set SiteProcess [exec hciprocstatus]} cerr]} {
            puts "[catch {set SiteProcess [exec hciprocstatus]}]"
            echo "cerr=$cerr"
#echo "Warning: cannot contact processes names via procstatus"
            puts "Default branch."
            set ProcessNotRunning 1
            set NetFile $rootdir/$site/NetConfig
            echo "getting thread names from NetConfig file=$NetFile"
            set SiteProcess [exec /bin/grep "^process" $NetFile]
            #regsub -all -nocase -- process $SiteProcess "" SiteProcess
            regsub -all -- {\{} $SiteProcess "" SiteProcess
        } else {
            # Customization since Centra has long process names
            set NetFile $rootdir/$site/NetConfig
            echo "getting thread names from NetConfig file=$NetFile"
            set SiteProcess [exec /bin/grep "^process" $NetFile]
            regsub -all -- {\{} $SiteProcess "" SiteProcess
            # End of Customization
            #regsub -all -- "    " $SiteProcess " " SiteProcess
            #regsub -all -- "   " $SiteProcess " " SiteProcess
            #regsub -all -- "  " $SiteProcess " " SiteProcess
            #set SiteProcess [join [lreplace [split $SiteProcess \n] 0 1 ] \n]
        }

set SiteProcList [split $SiteProcess \n]
echo "SiteProcList=$SiteProcList"