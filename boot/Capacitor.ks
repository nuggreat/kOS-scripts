IF NOT SHIP:UNPACKED AND SHIP:LOADED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. PRINT "unpacked". }
IF NOT EXISTS("1:/lib/") {CREATEDIR("1:/lib/").}
DELETEPATH("1:/boot").
COPYPATH("0:/Capacitor_Control.ks","1:/").
SET CORE:BOOTFILENAME TO "Capacitor_Control.ks".
REBOOT.