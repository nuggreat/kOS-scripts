WAIT 5.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 1.
BRAKES ON.
SAS ON.
IF NOT EXISTS("1:/lib/") {CREATEDIR("1:/lib/").}
COPYPATH("0:/boot/Post Startup Bootfiles/ablank.ks","1:/").
COPYPATH("0:/lib/lib_file_util.ks","1:/lib/").
//DELETEPATH("1:/boot/b_aircraft.ks").
COPYPATH("0:/lib/lib_navball.ks","1:/lib/").
COPYPATH("0:/lib/lib_navball2.ks","1:/lib/").
//COPYPATH("0:/autoP_Mk2.ks","1:/").
//COPYPATH("0:/autoP_Mk3.ks","1:/").
//COPYPATH("0:/autoP_Mk4.ks","1:/").
COPYPATH("0:/autoP_Mk5.ks","1:/").
//COPYPATH("0:/test.ks","1:/").
COPYPATH("0:/updater.ks","1:/").
COPYPATH("0:/air_info.ks","1:/").
COPYPATH("0:/lib/lib_formating.ks","1:/lib").

//MOVEPATH("1:/autoPilotMk2.ks","auto.ks").
//MOVEPATH("1:/autoPilotMk3.ks","auto.ks").
//MOVEPATH("1:/autoPilotMk4.ks","auto.ks").
//MOVEPATH("1:/autoPilotMk5.ks","auto.ks").

SET CORE:BOOTFILENAME TO "blank.ks".
UNLOCK STEERING.
//WAIT UNTIL ALTITUDE > 1000.
//REBOOT.

//STAGE.
//WAIT 1.
//BRAKES OFF.
//SAS OFF.
//LOCK STEERING TO HEADING(90.38,0).
//WAIT UNTIL GROUNDSPEED > 60.
//LOCK STEERING TO HEADING(90.38,5).
//WAIT UNTIL ALTITUDE > 100.
////UNLOCK STEERING.
//GEAR OFF.
////WAIT UNTIL ALTITUDE > 200.
//UNLOCK STEERING.
//RUN auto(LATLNG(15,-70),20,25,60,750,60).
////WAIT 1.
//LOCAL ksc IS "KSC".
//RUN auto(ksc,20,25,60,750,60).