IF NOT EXISTS("1:/lib/") {CREATEDIR("1:/lib/").}

COPYPATH("0:/boot/Post Startup Bootfiles/ablank.ks","1:/").
COPYPATH("0:/lib/lib_file_util.ks","1:/lib/").
COPYPATH("0:/lib/lib_land_v3.ks","1:/lib/").
COPYPATH("0:/lib/lib_rocket_utilities.ks","1:/lib/").
COPYPATH("0:/lib/lib_navball2.ks","1:/lib/").
//COPYPATH ("0:/lib/lib_dock.ks","1:/lib").
//COPYPATH ("0:/dock_station","1:/").
//COPYPATH ("0:/dock_ship","1:/").
COPYPATH ("0:/test_land.ks","1:/").
COPYPATH ("0:/node_burn.ks","1:/").
COPYPATH ("0:/land_at.ks","1:/").
COPYPATH ("0:/landing_v3.ks","1:/").
//COPYPATH ("0:/threaded_prime.ks","1:/").
//COPYPATH ("0:/threaded_prime_v2.ks","1:/").
//COPYPATH ("0:/prime.ks","1:/").
COPYPATH ("0:/updater.ks","1:/").
COPYPATH ("0:/file_util.ks","1:/").

//RUN file_util.
SET CORE:BOOTFILENAME TO "updater.ks".
//RUN threaded_prime_v2.

//WAIT 5.
//COPYPATH ("0:/test.ks","1:/").
//run test.