IF NOT SHIP:UNPACKED AND SHIP:LOADED { PRINT "waiting for unpack". WAIT UNTIL SHIP:UNPACKED AND SHIP:LOADED. WAIT 1. PRINT "unpacked". }
IF NOT EXISTS("1:/lib/") {CREATEDIR("1:/lib/").}       //creates lib sub directory on local volume
//DELETEPATH("1:/boot/rocket.ks").
COPYPATH("0:/boot/Post Startup Bootfiles/ablank.ks","1:/").
COPYPATH("0:/lib/lib_file_util.ks","1:/lib/").
COPYPATH("0:/updater.ks","1:/").
COPYPATH("0:/lib/lib_navball.ks","1:/lib/").
COPYPATH("0:/lib/lib_navball2.ks","1:/lib/").
COPYPATH("0:/lib/lib_rocket_utilities.ks","1:/lib").
COPYPATH("0:/lift_off.ks","1:").
COPYPATH("0:/node_burn.ks","1:/").
COPYPATH("0:/lib/lib_formating.ks","1:/lib").
COPYPATH("0:/lib/lib_land_vac.ks","1:/lib/").
COPYPATH("0:/landing_vac.ks","1:/").
COPYPATH("0:/lib/lib_dock.ks","1:/lib").
COPYPATH("0:/dock_ship.ks","1:/").
COPYPATH("0:/land_at.ks","1:/").
COPYPATH("0:/deorbit.ks","1:/").
COPYPATH("0:/rover.ks","1:/").
COPYPATH("0:/fuel_pump.ks","1:/").
COPYPATH("0:/dock_station.ks","1:/").
COPYPATH("0:/lib/lib_land_atm.ks","1:/lib/").
COPYPATH("0:/landing_atm.ks","1:/").
COPYPATH("0:/file_util.ks","1:/").
COPYPATH("0:/prime.ks","1:/").
SET CORE:BOOTFILENAME TO "ablank.ks".
IF SHIP:BODY = BODY("Kerbin") {
	RUN lift_off(80,90).
} ELSE IF SHIP:BODY = BODY("Mun") OR SHIP:BODY = BODY("Minmus") {
	RUN lift_off(30,90).
}