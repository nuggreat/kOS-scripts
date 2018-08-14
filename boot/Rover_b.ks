IF NOT SHIP:UNPACKED AND SHIP:LOADED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. PRINT "unpacked". }
IF NOT EXISTS("1:/lib/") {CREATEDIR("1:/lib/").}
COPYPATH("0:/boot/Post Startup Bootfiles/ablank.ks","1:/").
COPYPATH("0:/lib/lib_file_util.ks","1:/lib/").
COPYPATH("0:/lib/lib_navball.ks","1:/lib/").
COPYPATH("0:/lib/lib_formating.ks","1:/lib").
COPYPATH("0:/lib/lib_rocket_utilities.ks","1:/").
COPYPATH("0:/lib/lib_geochordnate.ks","1:/lib").
COPYPATH("0:/rover.ks","1:/").
COPYPATH("0:/updater.ks","1:/").

SET CORE:BOOTFILENAME TO "ablank.ks".