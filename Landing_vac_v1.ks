PARAMETER retroMargin IS 100.	//the distance above the gound that the ship will come to during the retroburn
FOR lib IN LIST("lib_land_vac_v1","lib_navball2","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
control_point().
SAS OFF.
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 20.
WAIT UNTIL active_engine().
LOCK STEERING TO SHIP:SRFRETROGRADE.
LOCAL vertMargin IS lowist_part(SHIP) + 7.5.	//Sets the margen for the Sucide Burn and Final Decent
LOCAL shipISP IS isp_calc().
LOCAL timePre IS TIME:SECONDS.
LOCAL tsMax IS 0.5.
LOCAL deltaTime IS 0.5.
LOCAL simLex IS LEX("seconds", 30).
LOCAL stopGap IS 0.

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET landing_PID TO PIDLOOP(0.5,0.1,0.01,0,1).

//start of core logic
LOCAL done IS FALSE.
UNTIL done {	//waiting until altitude deturmined by the sim is below the retroMargin
	WAIT 0.01.
	SET deltaTime TO (TIME:SECONDS - timePre + deltaTime) / 2.
	SET timePre TO TIME:SECONDS.
	SET tsMax TO (tsMax + (simLex["seconds"] / 10)) / 2.
	LOCAL shipPos IS SHIP:POSITION.
	LOCAL initalMass IS SHIP:MASS.
	SET simLex TO sim_land_spot(SHIP,shipISP,MIN(deltaTime,tsMax),deltaTime).
	LOCAL stopPos IS shipPos + simLex["pos"].
	SET stopGap TO SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT.
	CLEARSCREEN.
	PRINT "Terrain Gap:   " + ROUND(stopGap).
	PRINT "Dv Needed:     " + ROUND(shipISP*9.806*LN(initalMass/simLex["mass"])).
	PRINT " ".
	PRINT "Time to Stop:  " + ROUND(simLex["seconds"],1).
	PRINT "Time Per Sim:  " + ROUND(deltaTime,2).
	PRINT "Steps Per Sim: " + simLex["cycles"].
	SET done TO stopGap < retroMargin.
}
GEAR ON.
LIGHTS ON.
LOCK STEERING TO SHIP:SRFRETROGRADE.

LOCK THROTTLE TO MIN(100 / (MAX(stopGap - (retroMargin - 100),1)), 1).
LOCAL done IS FALSE.
UNTIL done {	//retrograde burn until vertical speed is greater than -2
	SET deltaTime TO (TIME:SECONDS - timePre + deltaTime) / 2.
	SET timePre TO TIME:SECONDS.
	SET tsMax TO (tsMax + (simLex["seconds"] / 10)) / 2.
	LOCAL shipPos IS SHIP:POSITION.
	LOCAL initalMass IS SHIP:MASS.
	SET simLex TO sim_land_spot(SHIP,shipISP,MIN(deltaTime,tsMax),0).
	LOCAL stopPos IS shipPos + simLex["pos"].
	SET stopGap TO SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT.
	CLEARSCREEN.
	PRINT "Terrain Gap:   " + ROUND(stopGap).
	PRINT "Dv Needed:     " + ROUND(shipISP*9.806*LN(initalMass/simLex["mass"])).
	PRINT " ".
	PRINT "time to Stop:  " + ROUND(simLex["seconds"],1).
	PRINT "Time Per Sim:  " + ROUND(deltaTime,2).
	PRINT "Steps Per Sim: " + simLex["cycles"].
	PRINT "Vert Speed:    " + ROUND(VERTICALSPEED).
	SET done TO VERTICALSPEED > -2 AND GROUNDSPEED < 10.
}
UNLOCK THROTTLE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

LOCAL shipThrust IS SHIP:AVAILABLETHRUST * 0.95.
LOCAL sucideMargin IS vertMargin + 10.
SET landing_PID:SETPOINT TO sucideMargin - 0.1.
LOCAL done IS FALSE.
UNTIL done {	//sucide burn stotoping at 25m above surface
	LOCAL decentLex IS decent_math(shipThrust).

	LOCK THROTTLE TO landing_PID:UPDATE(TIME:SECONDS,ALT:RADAR - decentLex["stopDist"]).
	CLEARSCREEN.
	PRINT "Altitude:     " + ROUND(ALT:RADAR,1).
	PRINT "Stoping Dist: " + ROUND(decentLex["stopDist"],1).
	PRINT "Stoping Time: " + ROUND(decentLex["stopTime"],1).
	PRINT "Dist to Burn: " + ROUND(ALT:RADAR - sucideMargin - decentLex["stopDist"],1).
	WAIT 0.01.
	SET done TO ALT:RADAR < sucideMargin.
}
landing_PID:RESET().

LOCAL steeringTar IS LOOKDIRUP(SHIP:SRFRETROGRADE:FOREVECTOR:NORMALIZED + (SHIP:UP:FOREVECTOR:NORMALIZED * 3),SHIP:NORTH:FOREVECTOR).
LOCK STEERING TO steeringTar.
LOCAL done IS FALSE.
UNTIL done {	//slow decent until tuchdown
	LOCAL decentLex IS decent_math(shipThrust).

	LOCAL vSpeedTar IS MIN(0 - (ALT:RADAR - vertMargin - (ALT:RADAR * decentLex["stopTime"])) / (11 - MIN(decentLex["twr"],10)),-0.2).
	SET landing_PID:SETPOINT TO vSpeedTar.
	LOCK THROTTLE TO landing_PID:UPDATE(TIME:SECONDS,VERTICALSPEED).

	IF VERTICALSPEED < -1 {
		SET steeringTar TO LOOKDIRUP(SHIP:SRFRETROGRADE:FOREVECTOR:NORMALIZED + (SHIP:UP:FOREVECTOR:NORMALIZED * 3),SHIP:NORTH:FOREVECTOR).
	} ELSE {
		LOCAL retroHeading IS heading_of_vector(SHIP:SRFRETROGRADE:FOREVECTOR).
		LOCAL adjustedPitch IS MAX(90-GROUNDSPEED,89).
		SET steeringTar TO LOOKDIRUP(HEADING(retroHeading,adjustedPitch):FOREVECTOR,SHIP:NORTH:FOREVECTOR).
	}

	CLEARSCREEN.
	PRINT "Altitude:  " + ROUND(ALT:RADAR,1).
	PRINT "vSpeedTar: " + ROUND(vSpeedTar,1).
	PRINT "vSpeed:    " + ROUND(VERTICALSPEED,1).
	WAIT 0.01.
	SET done TO STATUS = "LANDED" OR STATUS = "SPLASHED".
}
UNLOCK THROTTLE.
UNLOCK STEERING.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
LIGHTS OFF.
BRAKES ON.
//SAS ON.
//end of core logic start of functions
FUNCTION decent_math {	// the math needed for sucide burn and fine decent
	PARAMETER shipThrust.
	LOCAL localGrav IS SHIP:BODY:MU/(SHIP:BODY:RADIUS + SHIP:ALTITUDE)^2.	//calculates gravity of the body
	LOCAL shipAcceleration IS shipThrust / SHIP:MASS.						//ship acceleration in m/s
	LOCAL stopTime IS  ABS(VERTICALSPEED) / (shipAcceleration - localGrav).//time needed to nutrlise vertical speed
	LOCAL stopDist IS 1/2 * shipAcceleration * stopTime * stopTime.			//how much distance is needed to come to a stop
	LOCAL twr IS shipAcceleration / localGrav.					//the TWR of the craft based on local gravity
	RETURN LEX("stopTime",stopTime,"stopDist",stopDist,"twr",twr).
}

FUNCTION lowist_part {	//returns the largist dist from the COM for a part in the retrograde direction
	PARAMETER craft.
	LOCAL biggest IS 0.
	LOCAL aft_unit IS (-1)*craft:FACING:FOREVECTOR. // unit vec in aft direction.
	FOR p IN craft:PARTS {
		LOCAL aft_dist IS VDOT(p:POSITION, aft_unit). // distance in terms of aft-ness.
		IF aft_dist > biggest {
			SET  biggest TO aft_dist.
		}
	}
	RETURN biggest.
}