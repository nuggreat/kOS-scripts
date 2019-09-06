PARAMETER warping IS FALSE,landingTar IS FALSE,retroMargin IS 100.	//the distance above the gound that the ship will come to during the retroburn
IF NOT EXISTS ("1/lib/lib_geochordnate.ks") { COPYPATH("0:/lib/lib_geochordnate.ks","1:/lib/lib_geochordnate.ks"). }
FOR lib IN LIST("lib_land_vac","lib_navball2","lib_rocket_utilities","lib_geochordnate") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
control_point().
SAS OFF.
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 20.
WAIT UNTIL active_engine().
LOCAL vertMargin IS lowist_part(SHIP) + 2.5.	//Sets the margin for the Sucide Burn and Final Decent
SET retroMargin TO retroMargin + vertMargin.
LOCAL retroMarginLow IS retroMargin - 100.
LOCAL shipISP IS isp_calc().
LOCAL timePre IS TIME:SECONDS.
LOCAL tsMax IS 0.5.
LOCAL deltaTime IS 0.5.
LOCAL simResults IS LEX("pos",SHIP:POSITION,"seconds", 30).
LOCAL stopGap IS 0.
LOCAL pitchOffset IS 0.
LOCAL headingOffset IS 0.
LOCAL throt IS 1.
LOCAL landingChord IS FALSE.
LOCAL engineOn IS FALSE.
SET simDelay TO 1.

//PID setup PIDLOOP(kP,kI,kD,min,max)
GLOBAL landing_PID IS PIDLOOP(1.1,0.1,0.1,0,1).//was(0.5,0.1,0.01,0,1)
GLOBAL pitch_PID IS PIDLOOP(0.04,0.0005,0.075,-5,15).
GLOBAL heading_pid IS PIDLOOP(0.04,0.0005,0.075,-10,10).

//start of core logic
LOCAL haveTarget IS FALSE.
IF NOT landingTar:ISTYPE("boolean") {
	SET landingData TO mis_types_to_geochordnate(landingTar,FALSE).
	SET landingChord TO landingData["chord"].
	IF landingChord:ISTYPE("geocoordinates") {
		SET haveTarget TO TRUE.
	} ELSE {
		PRINT "No Target Set".
	}
}

WHEN when_triger(simResults["pos"],retroMargin) THEN {
	LOCK THROTTLE TO throt.
	SET engineOn TO TRUE.
	SET simDelay TO 0.
	GEAR ON.
	LIGHTS ON.
	WAIT 0.
}

IF haveTarget { LOCK STEERING TO adjusted_retorgrade(headingOffset,pitchOffset). } ELSE { LOCK STEERING TO SHIP:SRFRETROGRADE. }

SET NAVMODE TO "SURFACE".
//LOCAL done IS FALSE.
UNTIL VERTICALSPEED > -2 AND GROUNDSPEED < 10 {	//retrograde burn until vertical speed is greater than -2
	LOCAL localTime IS TIME:SECONDS.
	SET deltaTime TO (localTime - timePre + deltaTime) / 2.
	SET timePre TO localTime.
	LOCAL shipPosOld IS SHIP:POSITION - SHIP:BODY:POSITION.
	LOCAL initalMass IS SHIP:MASS.
	SET tsMax TO (tsMax + (simResults["seconds"] / 10)) / 2.
	SET simResults TO sim_land_vac(SHIP,shipISP,MIN(deltaTime,tsMax),deltaTime * simDelay).
	LOCAL stopPos IS (SHIP:BODY:POSITION + shipPosOld) + simResults["pos"].
	SET stopGap TO SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT.
	SET throt TO MIN(100 / MAX((stopGap - retroMarginLow), 100),1).
	CLEARSCREEN.
	PRINT "Terrain Gap:    " + ROUND(stopGap).
	PRINT "Dv Needed:      " + ROUND(shipISP*9.80665*LN(initalMass/simResults["mass"])).
	PRINT " ".
	PRINT "time to Stop:   " + ROUND(simResults["seconds"],1).
	PRINT "Time Per Sim:   " + ROUND(deltaTime,2).
	PRINT "Steps Per Sim:  " + simResults["cycles"].
	PRINT "Vert Speed:     " + ROUND(VERTICALSPEED).
	IF warping {
		SET KUNIVERSE:TIMEWARP:WARP TO MIN(MAX(CEILING(stopGap / ABS(VERTICALSPEED * 60)) - 1,0),4).
	} ELSE IF KUNIVERSE:TIMEWARP:WARP > 1 AND ABS(stopGap / VERTICALSPEED) < 60 {
		IF NOT engineOn {
			SET KUNIVERSE:TIMEWARP:WARP TO 0.
		}
	}
	IF haveTarget AND engineOn {
		PRINT " ".
		LOCAL distVec IS  stopPos - landingChord:ALTITUDEPOSITION(retroMargin).
		LOCAL positionUpVec IS (stopPos - SHIP:BODY:POSITION):NORMALIZED.
		LOCAL retrogradeVec IS SHIP:SRFRETROGRADE:FOREVECTOR.
//		LOCAL leftVec IS VCRS(retrogradeVec,SHIP:UP:FOREVECTOR).//vector normal to retrograde and up
//		LOCAL retroVec IS VCRS(SHIP:UP:FOREVECTOR,leftVec).//retrograde vector parallel to the ground
		LOCAL leftVec IS VCRS(retrogradeVec,positionUpVec):NORMALIZED.//vector normal to retrograde and up
		LOCAL retroVec IS VCRS(positionUpVec,leftVec):NORMALIZED.//retrograde vector parallel to the ground
		LOCAL pitchOffsetRaw IS VDOT(distVec, retroVec).	//if positive then will land short, if negative than will land long
		LOCAL PIDclamp IS MAX(stopGap / (retroMargin / 5),0).
		SET pitch_PID:MINOUTPUT TO MIN(MAX(-PIDclamp,-5),0).
		SET heading_pid:MINOUTPUT TO MIN(MAX(-PIDclamp,-10),0).
		SET heading_pid:MAXOUTPUT TO MIN(MAX(PIDclamp,0),10).
		SET pitchOffset TO pitch_PID:UPDATE(TIME:SECONDS,-pitchOffsetRaw).
		LOCAL headingOffsetRaw IS VDOT(distVec, leftVec).	//if positive then landingChord is to the left, if negative landingChord is to the right
		SET headingOffset TO heading_pid:UPDATE(TIME:SECONDS,-headingOffsetRaw).
		PRINT "pitchAdjustRaw:   " + ROUND(pitchOffsetRaw).
		PRINT "Pitch   Offset:   " + ROUND(pitchOffset,2).
		PRINT "headingAdjustRaw: " + ROUND(headingOffsetRaw).
		PRINT "Heading   Offset: " + ROUND(headingOffset,2).
		PRINT "Distance:         " + ROUND(landingChord:DISTANCE).
	}
	//SET done TO VERTICALSPEED > -2 AND GROUNDSPEED < 10.
}

UNLOCK THROTTLE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

LOCAL shipThrust IS SHIP:AVAILABLETHRUST * 0.90.
LOCAL srfGrav IS SHIP:BODY:MU/(SHIP:BODY:RADIUS)^2.
LOCAL shipAcc IS (shipThrust / SHIP:MASS).
LOCAL sucideMargin IS vertMargin + 7.5.
LOCAL decentLex IS decent_math(shipThrust,srfGrav).
LOCK STEERING TO LOOKDIRUP(SHIP:SRFRETROGRADE:FOREVECTOR,SHIP:NORTH:FOREVECTOR).
//SET landing_PID:SETPOINT TO sucideMargin - 0.1.
LOCK THROTTLE TO landing_PID:UPDATE(TIME:SECONDS,VERTICALSPEED).
//LOCK THROTTLE TO landing_PID:UPDATE(TIME:SECONDS,ALT:RADAR - decentLex["stopDist"]).
UNTIL ALT:RADAR < sucideMargin {	//vertical suicide burn stopping at about 10m above surface
	SET decentLex TO decent_math(shipThrust,srfGrav).
	SET shipAcc TO decentLex["acc"].
	SET landing_PID:SETPOINT TO MIN(-shipAcc * SQRT(ABS(2 * (ALT:RADAR - sucideMargin) / shipAcc)),-0.5).
	CLEARSCREEN.
	PRINT "setPoint:     " + ROUND(landing_PID:SETPOINT,2).
	PRINT "vSpeed:       " + ROUND(VERTICALSPEED,2).
	PRINT "Altitude:     " + ROUND(ALT:RADAR - sucideMargin,1).
	PRINT "Stoping Dist: " + ROUND(decentLex["stopDist"],1).
	PRINT "Stoping Time: " + ROUND(decentLex["stopTime"],1).
	PRINT "Dist to Burn: " + ROUND(ALT:RADAR - sucideMargin - decentLex["stopDist"],1).
	WAIT 0.01.
}
//landing_PID:RESET().

LOCAL steeringTar IS LOOKDIRUP(SHIP:SRFRETROGRADE:FOREVECTOR:NORMALIZED + (SHIP:UP:FOREVECTOR:NORMALIZED * 3),SHIP:NORTH:FOREVECTOR).
LOCK STEERING TO steeringTar.
//LOCK THROTTLE TO landing_PID:UPDATE(TIME:SECONDS,VERTICALSPEED).
//LOCAL done IS FALSE.
UNTIL STATUS = "LANDED" OR STATUS = "SPLASHED" {	//slow decent until touchdown
	LOCAL decentLex IS decent_math(shipThrust,srfGrav).

	LOCAL vSpeedTar IS MIN(0 - (ALT:RADAR - vertMargin - (ALT:RADAR * decentLex["stopTime"])) / (11 - MIN(decentLex["twr"],10)),-0.5).
	SET landing_PID:SETPOINT TO vSpeedTar.

	IF VERTICALSPEED < -1 {
		SET steeringTar TO LOOKDIRUP(SHIP:SRFRETROGRADE:FOREVECTOR:NORMALIZED + (SHIP:UP:FOREVECTOR:NORMALIZED * 3),SHIP:NORTH:FOREVECTOR).
	} ELSE {
		LOCAL retroHeading IS heading_of_vector(SHIP:SRFRETROGRADE:FOREVECTOR).
		LOCAL adjustedPitch IS MAX(90-GROUNDSPEED,89).
		SET steeringTar TO LOOKDIRUP(HEADING(retroHeading,adjustedPitch):FOREVECTOR,SHIP:NORTH:FOREVECTOR).
	}

	WAIT 0.01.
	CLEARSCREEN.
	PRINT "Altitude:  " + ROUND(ALT:RADAR,1).
	PRINT "vSpeedTar: " + ROUND(vSpeedTar,1).
	PRINT "vSpeed:    " + ROUND(VERTICALSPEED,1).
}

BRAKES ON.
PRINT "Holding Up Until Craft Stops Moving".
LOCK THROTTLE TO 0.
LOCK STEERING TO LOOKDIRUP(SHIP:UP:FOREVECTOR,SHIP:NORTH:FOREVECTOR).
WAIT 5.
ABORT OFF.
PRINT "Actvate ABORT to Skip Wait".
WAIT UNTIL SHIP:VELOCITY:SURFACE:MAG < 0.1 OR ABORT.

UNLOCK THROTTLE.
UNLOCK STEERING.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
LIGHTS OFF.
//SAS ON.

//end of core logic start of functions
FUNCTION decent_math {// the math needed for suicide burn and final decent
	PARAMETER shipThrust,localGrav.
	LOCAL shipAcc IS (shipThrust / SHIP:MASS) - localGrav.	//ship acceleration in m/s
	LOCAL stopTime IS  ABS(VERTICALSPEED) / shipAcc.		//time needed to neutralize vertical speed
	LOCAL stopDist IS 1/2 * shipAcc * stopTime * stopTime.	//how much distance is needed to come to a stop
	LOCAL twr IS (shipAcc / localGrav) + 1.						//the TWR of the craft based on local gravity
	RETURN LEX("stopTime",stopTime,"stopDist",stopDist,"twr",twr,"acc",(shipAcc - localGrav)).
}

FUNCTION lowist_part {//returns the largest dist from the root part for a part in the backward direction
	PARAMETER craft IS SHIP.
	LOCAL largest IS 0.
	FOR par IN craft:PARTS {
		LOCAL aft_dist IS VDOT((craft:ROOTPART:POSITION - par:POSITION), craft:FACING:FOREVECTOR).
		IF aft_dist > largest {
			SET largest TO aft_dist.
		}
	}
	RETURN largest.
}

FUNCTION adjusted_retorgrade {
	PARAMETER yawOffset,pitchOffset.//positive yaw is yawing to the right, positive pitch is pitching up
	LOCAL returnDir IS ANGLEAXIS(-pitchOffset,SHIP:SRFRETROGRADE:STARVECTOR) * SHIP:SRFRETROGRADE.
	RETURN ANGLEAXIS(yawOffset,returnDir:TOPVECTOR) * returnDir.
}

FUNCTION when_triger {
	PARAMETER simPos,vertMargin.
	LOCAL stopPos IS SHIP:POSITION + simPos.
	RETURN (SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT) < vertMargin.
}