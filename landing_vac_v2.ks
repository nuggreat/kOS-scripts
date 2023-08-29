PARAMETER warping IS FALSE,landingTarget IS FALSE,retroMargin IS 100.	//the distance above the gound that the ship will come to during the retroburn
FOR lib IN LIST("lib_land_vac","lib_navball2","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
control_point().
SAS OFF.
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 20.
WAIT UNTIL active_engine().
LOCK STEERING TO SHIP:SRFRETROGRADE.
LOCAL vertMargin IS lowist_part(SHIP) + 7.5.	//Sets the margin for the Sucide Burn and Final Decent
LOCAL shipISP IS isp_calc().
LOCAL timePre IS TIME:SECONDS.
LOCAL tsMax IS 0.5.
LOCAL deltaTime IS 0.5.
LOCAL simResults IS LEX("seconds", 30).
LOCAL stopGap IS 0.
LOCAL pitchOffset IS 0.
LOCAL headingOffset IS 0.

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET landing_PID TO PIDLOOP(0.5,0.1,0.01,0,1).
SET pitch_PID TO PIDLOOP(0.04,0.0005,0.075,-5,25).//was 0.04,0.0005,0.075
SET heading_pid TO PIDLOOP(0.04,0.0005,0.075,-5,5).

//start of core logic
LOCAL haveTarget IS FALSE.
IF NOT landingTarget:ISTYPE("boolean") { SET haveTarget TO TRUE. }

SET NAVMODE TO "SURFACE".
LOCAL done IS FALSE.
UNTIL done {	//waiting until altitude deturmined by the sim is below the retroMargin
	WAIT 0.01.
	SET deltaTime TO (TIME:SECONDS - timePre + deltaTime) / 2.
	SET timePre TO TIME:SECONDS.
	SET tsMax TO (tsMax + (simResults["seconds"] / 10)) / 2.
//	LOCAL shipPos IS SHIP:POSITION.
	LOCAL shipPos IS SHIP:POSITION - SHIP:BODY:POSITION.
	LOCAL initalMass IS SHIP:MASS.
	SET simResults TO sim_land_spot(SHIP,shipISP,MIN(deltaTime,tsMax),deltaTime).
//	LOCAL stopPos IS shipPos + simResults["pos"].
	LOCAL stopPos IS shipPos + SHIP:BODY:POSITION + simResults["pos"].
	SET stopGap TO SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT.
	CLEARSCREEN.
	PRINT "Terrain Gap:    " + ROUND(stopGap).
	PRINT "Dv Needed:      " + ROUND(shipISP*9.806*LN(initalMass/simResults["mass"])).
	PRINT " ".
	PRINT "Time to Stop:   " + ROUND(simResults["seconds"],1).
	PRINT "Time Per Sim:   " + ROUND(deltaTime,2).
	PRINT "Steps Per Sim:  " + simResults["cycles"].
	PRINT "Landing Target: " + haveTarget.
	IF warping { SET KUNIVERSE:TIMEWARP:WARP TO MIN(MAX(CEILING(stopGap / ABS(VERTICALSPEED * 60)) - 1,0),3). }
	SET done TO stopGap < retroMargin.
}
GEAR ON.
LIGHTS ON.
IF haveTarget { LOCK STEERING TO adjusted_retorgrade(headingOffset,pitchOffset). } ELSE { LOCK STEERING TO SHIP:SRFRETROGRADE. }

LOCAL throt IS MIN(100 / (MAX(stopGap - (retroMargin - 100),1)), 1).
LOCK THROTTLE TO throt.
LOCAL done IS FALSE.
UNTIL done {	//retrograde burn until vertical speed is greater than -2
	SET deltaTime TO (TIME:SECONDS - timePre + deltaTime) / 2.
	SET timePre TO TIME:SECONDS.
	SET tsMax TO (tsMax + (simResults["seconds"] / 10)) / 2.
	LOCAL shipPos IS SHIP:POSITION.
//	LOCAL shipPos IS SHIP:POSITION - SHIP:BODY:POSITION.
	LOCAL initalMass IS SHIP:MASS.
	SET simResults TO sim_land_spot(SHIP,shipISP,MIN(deltaTime,tsMax),0).
	LOCAL stopPos IS shipPos + simResults["pos"].
//	LOCAL stopPos IS shipPos + SHIP:BODY:POSITION + simResults["pos"].
	SET stopGap TO SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT.
	SET throt TO MIN(100 / (MAX(stopGap - (retroMargin - 100),1)), 1).
	CLEARSCREEN.
	PRINT "Terrain Gap:    " + ROUND(stopGap).
	PRINT "Dv Needed:      " + ROUND(shipISP*9.806*LN(initalMass/simResults["mass"])).
	PRINT " ".
	PRINT "time to Stop:   " + ROUND(simResults["seconds"],1).
	PRINT "Time Per Sim:   " + ROUND(deltaTime,2).
	PRINT "Steps Per Sim:  " + simResults["cycles"].
	PRINT "Vert Speed:     " + ROUND(VERTICALSPEED).
	IF haveTarget {
		PRINT " ".
		LOCAL distVec IS  stopPos - landingTarget:ALTITUDEPOSITION(retroMargin).
		LOCAL retrogradeVec IS SHIP:SRFRETROGRADE:FOREVECTOR.
		LOCAL leftVec IS VCRS(retrogradeVec,SHIP:UP:FOREVECTOR).//vector normal to retrograde and up
		LOCAL retroVec IS VCRS(SHIP:UP:FOREVECTOR,leftVec).//retrograde vector paralell to the ground
		LOCAL pitchOffsetRaw IS VDOT(distVec, retroVec).	//if positive then will land short, if negative than will land long
		SET pitch_PID:MINOUTPUT TO MIN(MAX(stopGap / (retroMargin / -5),-5),0).
		SET pitchOffset TO pitch_PID:UPDATE(TIME:SECONDS,-pitchOffsetRaw).
		LOCAL headingOffsetRaw IS VDOT(distVec, leftVec).	//if positive then landingTarget is to the left, if negative landingTarget is to the right
		SET headingOffset TO heading_pid:UPDATE(TIME:SECONDS,-headingOffsetRaw).
		PRINT "pitchAdjustRaw:   " + ROUND(pitchOffsetRaw).
		PRINT "Pitch   Offset:   " + ROUND(pitchOffset,2).
		PRINT "headingAdjustRaw: "  + ROUND(headingOffsetRaw).
		PRINT "Heading   Offset: " + ROUND(headingOffset,2).
		PRINT "Distance:         " + ROUND(landingTarget:DISTANCE).
	}
	SET done TO VERTICALSPEED > -2 AND GROUNDSPEED < 10.
}
UNLOCK THROTTLE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

LOCAL shipThrust IS SHIP:AVAILABLETHRUST * 0.95.
LOCAL sucideMargin IS vertMargin + 10.
LOCAL decentLex IS decent_math(shipThrust).
LOCK STEERING TO LOOKDIRUP(SHIP:SRFRETROGRADE:FOREVECTOR,SHIP:NORTH:FOREVECTOR).
SET landing_PID:SETPOINT TO sucideMargin - 0.1.
LOCK THROTTLE TO landing_PID:UPDATE(TIME:SECONDS,ALT:RADAR - decentLex["stopDist"]).
LOCAL done IS FALSE.
UNTIL done {	//sucide burn stotoping at 25m above surface
	SET decentLex TO decent_math(shipThrust).
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
LOCK THROTTLE TO landing_PID:UPDATE(TIME:SECONDS,VERTICALSPEED).
LOCAL done IS FALSE.
UNTIL done {	//slow decent until tuchdown
	LOCAL decentLex IS decent_math(shipThrust).

	LOCAL vSpeedTar IS MIN(0 - (ALT:RADAR - vertMargin - (ALT:RADAR * decentLex["stopTime"])) / (11 - MIN(decentLex["twr"],10)),-0.5).
	SET landing_PID:SETPOINT TO vSpeedTar.

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
//PRINT "Holding Up Until Craft Stops Moving".
//LOCK STEERING TO LOOKDIRUP(SHIP:UP:FOREVECTOR,SHIP:NORTH:FOREVECTOR).
//WAIT 5.
//ABORT OFF.
//PRINT "Actvate ABORT to Skip Wait".
//WAIT UNTIL SHIP:VELOCITY:SURFACE:MAG < 0.1 OR ABORT.
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

FUNCTION adjusted_retorgrade {
	PARAMETER headingOffset,pitchOffset.
	LOCAL returnDir IS ANGLEAXIS(-pitchOffset,SHIP:SRFRETROGRADE:STARVECTOR) * SHIP:SRFRETROGRADE.
	RETURN ANGLEAXIS(headingOffset,returnDir:TOPVECTOR) * returnDir.
}