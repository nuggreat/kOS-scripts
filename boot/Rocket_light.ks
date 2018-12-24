IF NOT SHIP:UNPACKED AND SHIP:LOADED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. PRINT "unpacked". }
IF NOT EXISTS("1:/lib/") {CREATEDIR("1:/lib/").}
DELETEPATH("1:/boot/rocket_light.ks").
COPYPATH("0:/boot/Post Startup Bootfiles/ablank.ks","1:/").
COMPILE PATH("0:/lib/lib_navball2.ks") TO PATH("1:/lib/lib_navball2.ksm").
COMPILE PATH("0:/lib/lib_rocket_utilities.ks") TO PATH("1:/lib/lib_rocket_utilities.ksm").
COMPILE PATH("0:/lib/lib_formating.ks") TO PATH("1:/lib/lib_formating.ksm").
COMPILE PATH("0:/lib/lib_file_util.ks") TO PATH("1:/lib/lib_file_util.ksm").
COMPILE PATH("0:/lib/lib_mis_utilities.ks") TO PATH("1:/lib/lib_mis_utilities.ksm").
COMPILE PATH("0:/lift_off.ks") TO PATH("1:/lift_off.ksm").
COMPILE PATH("0:/node_burn.ks") TO PATH("1:/node_burn.ksm").
COMPILE PATH("0:/updater.ks") TO PATH("1:/updater.ksm").
COMPILE PATH("0:/file_util.ks") TO PATH("1:/file_util.ksm").
SET CORE:BOOTFILENAME TO "ablank.ks".
IF SHIP:BODY = BODY("Kerbin") {
	RUN lift_off(80,90).
}