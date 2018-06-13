IF NOT SHIP:UNPACKED AND SHIP:LOADED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. PRINT "unpacked". }
IF NOT EXISTS("1:/lib/") {CREATEDIR("1:/lib/").}
DELETEPATH("1:/boot/default.ks").
COPYPATH("0:/boot/Post Startup Bootfiles/ablank.ks","1:/").
COMPILE PATH("0:/lib/lib_file_util.ks") TO PATH("1:/lib/lib_file_util.ksm").
COMPILE PATH("0:/file_util.ks") TO PATH("1:/file_util.ksm").
SET CORE:BOOTFILENAME TO "ablank.ks".