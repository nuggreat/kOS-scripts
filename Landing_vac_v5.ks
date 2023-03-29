PARAMETER warping TO FALSE,landingTar TO FALSE,retroMargin TO 100,thrustCoef TO 0.95.
copypath("0:/lib/lib_math_tools.ks","1:/lib/").
IF NOT EXISTS("1/lib/lib_geochordnate.ks") { COPYPATH("0:/lib/lib_geochordnate.ks","1:/lib/lib_geochordnate.ks"). }
FOR lib IN LIST("lib_land_vac_v3","lib_navball2","lib_rocket_utilities","lib_geochordnate","lib_math_tools") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
control_point().
SAS OFF.
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 30.
LOCAL gg0 TO CONSTANT:g0().
WAIT UNTIL active_engine().
LOCAL vertMargin TO lowist_part(SHIP) + 2.5.	//Sets the margin for the Sucide Burn and Final Decent
SET retroMargin TO retroMargin + vertMargin.
LOCAL retroMarginLow TO retroMargin - 100.
LOCAL localBody TO SHIP:BODY.

//time warp set up
LOCAL warpBase TO KUNIVERSE:TIMEWARP.
LOCAL railRateList TO warpBase:RAILSRATELIST.
LOCAL maxRate TO 3.
LOCAL factorThreshold TO 20.

// LOCAL logPath TO "0:/landingLog.csv".
// IF EXISTS(logPath) { DELETEPATH(logPath). }
// LOG "velAng,overshootError,simSeconds,dv" TO logPath.

//vars to start sim
LOCAL shipISP TO isp_calc().
LOCAL shipThrust IS SHIP:AVAILABLETHRUST.
LOCAL shipThrustFrac IS shipThrust * thrustCoef.
LOCAL shipPos TO SHIP:POSITION.
LOCAL shipVel TO SHIP:VELOCITY:ORBIT.
LOCAL bodyPos TO localBody:POSITION.
LOCAL deltaTime TO delta_time_init().
LOCAL dtFilter TO low_pass_filter_init(3,1).
LOCAL tsLimitFIlter IS low_pass_filter_init(5,1).

//sim result vars
// LOCAL radDelta TO delta_init(BODY:RADIUS).
// LOCAL radDeltaFilter IS low_pass_filter_init(SHIP:VERTICALSPEED,5)
LOCAL simResults TO LEX("pos",SHIP:POSITION,"seconds", 30).
LOCAL gm TO localBody:MU.
LOCAL stopPos TO SHIP:POSITION.
LOCAL stopGapRaw TO 0.
LOCAL stopGapFilter IS low_pass_filter_init(2,0).
LOCAL stopGapFiltered TO 0.
LOCAL altOffset TO 0.
LOCAL pitchOffset TO 0.
LOCAL headingOffset TO 0.
LOCAL throt TO 1.
LOCAL landingChord TO FALSE.
LOCAL engineOn TO FALSE.
LOCAL canWarp TO FALSE.
SET simDelay TO 1.

//PID setup PIDLOOP(kP,kI,kD,min,max)
GLOBAL landing_PID TO PIDLOOP(1.1,0.1,0.1,0,1).//was(0.5,0.1,0.01,0,1)
GLOBAL pitch_PID TO PIDLOOP(0.04,0.0005,0.075,-5,15).
GLOBAL heading_pid TO PIDLOOP(0.04,0.0005,0.075,-10,10).

//start of core logic
LOCAL haveTarget TO FALSE.
IF NOT landingTar:ISTYPE("boolean") {
	SET landingData TO mis_types_to_geochordnate(landingTar,FALSE).
	SET landingChord TO landingData["chord"].
	IF landingChord:ISTYPE("geocoordinates") {
		SET haveTarget TO TRUE.
	} ELSE {
		PRINT "No Target Set".
	}
}
//possibly add warp based ipu modification
WHEN TRUE THEN {
	LOCAL stopGap TO ((SHIP:ALTITUDE - altOffset) - localBody:GEOPOSITIONOF(stopPos):TERRAINHEIGHT) - retroMargin.
	IF canWarp {
		LOCAL burnEt TO stopGap / ABS(VERTICALSPEED).
		IF warping AND warpBase:ISSETTLED {
			// PRINT "be " + burnEt.
			// PRINT "wf " + warpFactor.
			IF (burnEt / railRateList[warpBase:WARP]) < factorThreshold {
				SET warpBase:WARP TO MAX(warpBase:WARP - 1,0).
			} ELSE IF (burnEt / railRateList[warpBase:WARP + 1]) > factorThreshold {
				SET warpBase:WARP TO MIN(warpBase:WARP + 1,maxRate).
			}
		}
	}
	IF (stopGap < 0) AND (warpBase:WARP = 0) {
		LOCK THROTTLE TO throt.
		SET engineOn TO TRUE.
		SET simDelay TO FALSE.
		GEAR ON.
		LIGHTS ON.
	} ELSE {
		RETURN TRUE.
	}
}

IF haveTarget {
	LOCK STEERING TO adjusted_retorgrade(headingOffset,pitchOffset).
} ELSE {
	LOCK STEERING TO SHIP:SRFRETROGRADE.
}

SET NAVMODE TO "SURFACE".
//LOCAL done TO FALSE.
UNTIL VERTICALSPEED > -2 AND GROUNDSPEED < 10 {	//retrograde burn until vertical speed is greater than -2
	SET localBody TO SHIP:BODY.
	LOCAL dt IS deltaTime().
	LOCAL tsLimit IS tsLimitFIlter(MAX(simResults["seconds"] / 10 - 0.1,1)).
	LOCAL ts IS MIN(dtFilter(dt * 2),tsLimit).

	WAIT 0.
	LOCAL solarPrime TO SOLARPRIMEVECTOR.
	IF simDelay {
		LOCAL startTime TO TIME:SECONDS + dt.
		SET shipPos TO POSITIONAT(SHIP, startTime).
		SET shipVel TO VELOCITYAT(SHIP, startTime):ORBIT.
	} ELSE {
		SET shipPos TO SHIP:POSITION.
		SET shipVel TO SHIP:VELOCITY:ORBIT.
	}
	SET bodyPos TO BODY:POSITION.
	LOCAL initalMass TO SHIP:MASS.
	LOCAL lowestMass TO SHIP:DRYMASS.

	SET simResults TO sim_land_vac(shipPos,shipVel,shipISP,shipThrustFrac,initalMass,lowestMass,bodyPos,BODY,solarPrime,ts,TRUE).

	SET stopPos TO simResults["pos"].
	SET stopGapRaw TO simResults["alt"] - localBody:GEOPOSITIONOF(stopPos):TERRAINHEIGHT.
	SET stopGapFiltered TO stopGapFilter(stopGapRaw).
	SET altOffset TO SHIP:ALTITUDE - simResults["alt"].
	SET canWarp TO warping.

	LOCAL gravAcc TO gm / simResults["rad"]^2.
	//equation is t = (sqrt(2*a*d + v^2) - v) / a,  the '- v' was changed to '+ v' to flip the sign on vertical speed
	//d = v * t + 0.5 * a * t^2
	
	// PRINT gravAcc.
	// PRINT stopGapFiltered.
	// PRINT retroMargin.
	// PRINT VERTICALSPEED.
	LOCAL burnEt TO (SQRT(MAX(2 * gravAcc * (stopGapFiltered - retroMargin) + VERTICALSPEED^2,0)) + VERTICALSPEED) / gravAcc.
	// PRINT initalMass.
	// PRINT simResults["mass"].
	// PRINT simResults["cycles"].
	SET burnDv TO shipISP*gg0*LN(initalMass/simResults["mass"]).

	CLEARSCREEN.
	PRINT "Terrain GapR:    " + ROUND(stopGapRaw).
	PRINT "Terrain GapF:    " + ROUND(stopGapFiltered).
	PRINT "Dv Needed:      " + ROUND(burnDv).
	PRINT " ".
	PRINT "time to Stop:   " + ROUND(simResults["seconds"],1).
	PRINT "Time Per Sim:   " + ROUND(dt,2).
	PRINT "time step:      " + ROUND(ts,2).
	PRINT "Steps Per Sim:  " + simResults["cycles"].
	PRINT "Vert Speed:     " + ROUND(VERTICALSPEED).
	PRINT "burn start et: " + ROUND(burnEt,2).
	IF RCS {
		KUNIVERSE:PAUSE.
	}

	SET throt TO (retroMargin) / MAX(stopGapRaw ,1).
	IF haveTarget AND engineOn {
		LOCAL distVec TO  stopPos - landingChord:ALTITUDEPOSITION(retroMargin).
		LOCAL positionUpVec TO (stopPos - SHIP:BODY:POSITION):NORMALIZED.
		LOCAL retrogradeVec TO SHIP:SRFRETROGRADE:FOREVECTOR.
		LOCAL upVec TO UP:VECTOR.
		LOCAL averageAcc IS (burnDv - gravAcc * simResults["seconds"]) / simResults["seconds"].


		LOCAL leftVec TO VCRS(retrogradeVec,positionUpVec):NORMALIZED.//vector normal to retrograde and up
		LOCAL retroVec TO VXCL(positionUpVec,retrogradeVec):NORMALIZED.//retrograde vector parallel to the ground
		LOCAL overshootError TO VDOT(distVec, retroVec).//if positive then will land short, if negative than will land long
		LOCAL lateralError TO VDOT(distVec, leftVec).//if positive then landingChord is to the left, if negative landingChord is to the right


		//arccos(adjacent/thrustCoef) = angle
		//angle
		//thrustCoef = fractional thrust feed into sim
		//solve for adjacent
		//adjacent/thrustCoef = cos(angle)
		//adjacent = cos(angled)*thrustCoef
		//
		//shipThrust = full thrust
		//arccos(adjacent/shipThrust) = fullAng

		// LOCAL shipThrust IS SHIP:AVAILABLETHRUST.
		// LOCAL shipThrustFrac IS shipThrust * thrustCoef.
		LOCAL velAng TO VANG(retrogradeVec, upVec).
		LOCAL vertThrustFrac TO COS(velAng) * thrustCoef.
		LOCAL fullAng TO ARCCOS(MAX(-1,MIN(1,vertThrustFrac))).
		
		LOCAL pitchMIN TO velAng - fullAng.
		SET pitchMIN TO MIN(MAX(stopGapRaw / retroMargin * -5, pitchMIN),15).
		LOCAL headingClamp TO MIN(MAX(SIN(-pitchMIN),0),10).

		// LOCAL pitchMIN TO MAX(stopGapRaw / (retroMargin / 5),0).
		LOCAL inlineAccChange TO 2 * overshootError / simResults["seconds"]^2.
		LOCAL inlineAcc TO SIN(velAng) * averageAcc.
		LOCAL vertAcc TO COS(velAng) * (averageAcc).
		LOCAL netInlineAcc TO inlineAcc - inlineAccChange.
		// LOCAL newPitchAng TO ARCTAN(MAX(-1,MIN(1,netInlineAcc / vertAcc))).
		LOCAL newPitchAng TO ARCTAN(netInlineAcc / vertAcc).
		SET pitchOffset TO MIN(MAX((velAng - newPitchAng) * 2,pitchMIN),15).


		// SET pitch_PID:MINOUTPUT TO MIN(MAX(-PIDclamp,-5),0).
		// SET pitchOffset TO pitch_PID:UPDATE(TIME:SECONDS,-overshootError).

		LOCAL lateralAcc IS 3 * (lateralError / simResults["seconds"]^2).
		SET headingOffset TO ARCSIN(MAX(MIN(lateralAcc / averageAcc,headingClamp),-headingClamp)).
		
		// LOG LIST(velAng,overshootError,simResults["seconds"],burnDv):JOIN(",") TO logPath.
		
		PRINT " ".
		PRINT "overshoot Error: " + ROUND(overshootError,2).
		PRINT "velAng: " + velAng.
		PRINT "inlineAccChange: " + inlineAccChange.
		PRINT "inlineAcc: " + inlineAcc.
		PRINT "vertAcc: " + vertAcc.
		PRINT "netInlineAcc: " + netInlineAcc.
		PRINT "newPitchAng: " + newPitchAng.
		PRINT "pitchMin: " + pitchMIN.
		PRINT "Pitch    Offset: " + ROUND(pitchOffset,2).
		PRINT "lateral   Error: " + ROUND(lateralError,2).
		PRINT "Heading  Offset: " + ROUND(headingOffset,2).
		PRINT "Distance:        " + ROUND(landingChord:DISTANCE).
	}
	//SET done TO VERTICALSPEED > -2 AND GROUNDSPEED < 10.
}

UNLOCK THROTTLE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

LOCAL shipThrust TO SHIP:AVAILABLETHRUST * 0.90.
LOCAL srfGrav TO SHIP:BODY:MU/(SHIP:BODY:RADIUS)^2.
LOCAL shipAcc TO (shipThrust / SHIP:MASS).
LOCAL sucideMargin TO vertMargin + 7.5.
LOCAL decentLex TO decent_math(shipThrust,srfGrav).
LOCK STEERING TO LOOKDIRUP(-SHIP:VELOCITY:SURFACE + UP:VECTOR,SHIP:NORTH:FOREVECTOR).
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
	PRINT "Stopping Dist: " + ROUND(decentLex["stopDist"],1).
	PRINT "Stopping Time: " + ROUND(decentLex["stopTime"],1).
	PRINT "Dist to Burn: " + ROUND(ALT:RADAR - sucideMargin - decentLex["stopDist"],1).
	WAIT 0.01.
}
//landing_PID:RESET().

LOCAL steeringTar TO LOOKDIRUP(SHIP:SRFRETROGRADE:FOREVECTOR + (SHIP:UP:FOREVECTOR * 3),SHIP:NORTH:FOREVECTOR).
LOCK STEERING TO steeringTar.
//LOCK THROTTLE TO landing_PID:UPDATE(TIME:SECONDS,VERTICALSPEED).
//LOCAL done TO FALSE.
UNTIL STATUS = "LANDED" OR STATUS = "SPLASHED" {	//slow decent until touchdown
	LOCAL decentLex TO decent_math(shipThrust,srfGrav).

	LOCAL vSpeedTar TO MIN(0 - (ALT:RADAR - vertMargin - (ALT:RADAR * decentLex["stopTime"])) / (11 - MIN(decentLex["twr"],10)),-0.5).
	SET landing_PID:SETPOINT TO vSpeedTar.

	IF VERTICALSPEED < -1 {
		SET steeringTar TO LOOKDIRUP(SHIP:SRFRETROGRADE:FOREVECTOR:NORMALIZED + (SHIP:UP:FOREVECTOR:NORMALIZED * 3),SHIP:NORTH:FOREVECTOR).
	} ELSE {
		LOCAL retroHeading TO heading_of_vector(SHIP:SRFRETROGRADE:FOREVECTOR).
		LOCAL adjustedPitch TO MAX(90-GROUNDSPEED,89).
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
	LOCAL shipAcc TO (shipThrust / SHIP:MASS) - localGrav.	//ship acceleration in m/s
	LOCAL stopTime TO  ABS(VERTICALSPEED) / shipAcc.		//time needed to neutralize vertical speed
	LOCAL stopDist TO 1/2 * shipAcc * stopTime * stopTime.	//how much distance is needed to come to a stop
	LOCAL twr TO (shipAcc / localGrav) + 1.						//the TWR of the craft based on local gravity
	RETURN LEX("stopTime",stopTime,"stopDist",stopDist,"twr",twr,"acc",(shipAcc - localGrav)).
}

FUNCTION lowist_part {//returns the largest dist from the root part for a part in the backward direction
	PARAMETER craft TO SHIP.
	LOCAL largest TO 0.
	FOR par IN craft:PARTS {
		LOCAL aftDist TO VDOT((craft:ROOTPART:POSITION - par:POSITION), craft:FACING:FOREVECTOR).
		IF aftDist > largest {
			SET largest TO aftDist.
		}
	}
	RETURN largest.
}

FUNCTION adjusted_retorgrade {
	PARAMETER yawOffset,pitchOffset.//positive yaw is yawing to the right, positive pitch is pitching up
	LOCAL returnDir TO ANGLEAXIS(-pitchOffset,SHIP:SRFRETROGRADE:STARVECTOR) * SHIP:SRFRETROGRADE.

	RETURN ANGLEAXIS(yawOffset,UP:VECTOR) * returnDir.
}