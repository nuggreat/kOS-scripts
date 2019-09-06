PARAMETER retroMargin IS 1000.
FOR lib IN LIST("lib_land_atm","lib_navball2","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNPATH("1:/lib/" + lib + ".ks"). }}
control_point().
//LOCAL retroMargin IS 100.	//the distance above the ground that the ship will come to during the retroburn
LOCAL decentMinSpeed IS 0.5.//the slowest the craft will go on the hover decent
LOCAL chuteTag IS "chute".	//the tag for what parachutes are to be used
SAS OFF.
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 20.
WAIT UNTIL active_engine().
LOCAL vertMargin IS lowist_part(SHIP) + 7.5.	//Sets the margin for the Suicide Burn and Final Decent
SET retroMargin TO retroMargin + vertMargin.
LOCAL retroMarginLow IS retroMargin - 100.
LOCAL shipISP IS isp_calc().
LOCAL localBody IS SHIP:BODY.
LOCAL timePre IS TIME:SECONDS.
LOCAL tsMax IS 2.
LOCAL speedAtm IS SHIP:VELOCITY:SURFACE:MAG.
LOCAL speedVac IS VELOCITYAT(SHIP,(1 + timePre)):SURFACE:MAG.
LOCAL shipMass IS SHIP:MASS.
LOCAL localAtm IS localBody:ATM.
LOCAL dragForce IS 0.
LOCAL dragCoef IS 0.
LOCAL stopGap IS 0.
LOCAL simStep IS 1.
LOCAL simPreTime IS 0.
LOCAL simResults IS LEX("pos",SHIP:POSITION,"seconds", 30).

LOCAL drawLex IS LEX().
CLEARVECDRAWS().

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET landing_PID TO PIDLOOP(0.5,0.1,0.05,0,1).


//need persistent vars
LOCAL preVel IS SHIP:VELOCITY:SURFACE.
LOCAL preTime IS TIME:SECONDS.
LOCAL preGravVec IS localBody:POSITION - SHIP:POSITION.
LOCAL preForeVec IS SHIP:FACING:FOREVECTOR.
LOCAL preMass IS SHIP:MASS.
LOCAL preDynamicP IS SHIP:Q * CONSTANT:ATMTOKPA.
LOCAL preAtmPressure IS MAX(localAtm:ALTITUDEPRESSURE(ALTITUDE) * CONSTANT:ATMTOKPA,0.000001).
LOCAL atmDencity IS preDynamicP / preVel:SQRMAGNITUDE.
LOCAL atmMolarMass IS atmDencity / preAtmPressure.

LOCAL throt IS 0.
LOCAL engineOn IS FALSE.
LOCAL simDelay IS 1.
WHEN when_triger(simResults["pos"],retroMargin + 1000) THEN {
	GEAR ON.
	LIGHTS ON.
	WHEN when_triger(simResults["pos"],retroMargin) THEN {
		LOCK THROTTLE TO throt.
		SET engineOn TO TRUE.
		SET simDelay TO 0.
	}
}

//start of core logic
LOCK STEERING TO SHIP:SRFRETROGRADE.
UNTIL (VERTICALSPEED > -2) AND (GROUNDSPEED < 10) {	//waiting until altitude determined by the sim is below the retroMargin
	//atmospheric calculations
	WAIT 0.
	LOCAL newTime IS TIME:SECONDS.
	LOCAL newDynamicP IS SHIP:Q.//is in atmospheres 
	LOCAL newVel IS SHIP:VELOCITY:SURFACE.
	LOCAL newAtmPressure IS MAX(localAtm:ALTITUDEPRESSURE(ALTITUDE),0.0000001).
	LOCAL newMass IS SHIP:MASS.
	LOCAL newForeVec IS SHIP:FACING:FOREVECTOR.
	LOCAL newGravVec IS localBody:POSITION - SHIP:POSITION.

	SET newAtmPressure TO newAtmPressure * CONSTANT:ATMTOKPA.
	SET newDynamicP TO newDynamicP * CONSTANT:ATMTOKPA.
	//SET newMass TO newMass * 1000.

	LOCAL avrPressure IS (newAtmPressure + preAtmPressure) / 2.
	LOCAL avrDynamicP IS (newDynamicP + preDynamicP) / 2.
	LOCAL avrForeVec IS ((newForeVec + preForeVec) / 2):NORMALIZED.
	SET shipISP TO isp_at(get_active_eng(),avrPressure).

	LOCAL deltaTime IS newTime - preTime.
	LOCAL gravVec IS average_grav(newGravVec:MAG,newGravVec:MAG) * (newGravVec:NORMALIZED + preGravVec:NORMALIZED):NORMALIZED * deltaTime.
	LOCAL burnDV IS shipISP * 9.80665 * LN(preMass / newMass).
	LOCAL accelVec IS avrForeVec * burnDV.
	LOCAL dragAcc IS (newVel - (preVel + gravVec + accelVec)) / deltaTime.
	LOCAL dragForce IS ((newMass + preMass) / 2) * VDOT(dragAcc,avrForeVec).
	SET atmDencity TO (avrDynamicP * 2) / ((newVel:SQRMAGNITUDE + preVel:SQRMAGNITUDE) / 2).//derived from q = d * v^2 / 2
	SET dragCoef TO dragForce / MAX(avrDynamicP,0.0001).
	SET atmMolarMass TO atmDencity / avrPressure.

	SET simPreTime TO TIME:SECONDS.
	SET simResults TO sim_land_atm(SHIP,dragCoef*0.8,atmMolarMass,simStep,deltaTime * simDelay,0.8).
	LOCAL simDelta IS TIME:SECONDS - simPreTime.
	SET simStep TO MIN((simDelta + simStep) / 2,simResults["seconds"] / 10).

	LOCAL stopPos IS (localBody:POSITION - newGravVec) + simResults["pos"].
	SET stopGap TO SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT.
	SET throt TO MIN(100 / MAX((stopGap - retroMarginLow), 100),1).

	//VecDrawAdd(drawLex,SHIP:POSITION,dragAcc*2,RED,"DragVec",1,1).
	//VecDrawAdd(drawLex,SHIP:POSITION,accelVec*2,GREEN,"burnVec",1,1).
	//VecDrawAdd(drawLex,SHIP:POSITION,dragAcc*10,RED,1,0).
	CLEARSCREEN.
	PRINT " ".
	PRINT "Terrain gap:  " + ROUND(stopGap).
	PRINT "Time to Stop: " + ROUND(simResults["seconds"],2).
	//PRINT "massBurned " + (simResults["mass"]).
	PRINT "Dv needed:    " + ROUND(shipISP * 9.80665 * LN(preMass/(MAX(simResults["mass"],0.0001)))).
	PRINT "Speed:        " + ROUND(newVel:MAG,1).
	//PRINT "Drag Force:   " + ROUND(dragForce,3).
	//PRINT "Drag Coeff:   " + dragCoef.
	//PRINT "atmDencity:   " + atmDencity.
	//PRINT "expended DV:  " + (burnDV).
	PRINT " ".
	PRINT "Sim Duration:  " + ROUND(simDelta,2).
	PRINT "Steps Per Sim: " + simResults["cycles"].

	SET preVel TO newVel.
	SET preTime TO newTime.
	SET preGravVec TO newGravVec.
	SET preForeVec TO newForeVec.
	SET preMass TO newMass.
	SET preDynamicP TO newDynamicP.
	SET preAtmPressure TO newAtmPressure.
}

UNLOCK THROTTLE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

LOCAL shipThrust IS SHIP:AVAILABLETHRUST.
LOCAL sucideMargin IS vertMargin + 10.
SET landing_PID:SETPOINT TO sucideMargin - 0.1.
LOCAL done IS FALSE.
UNTIL done {	//suicide burn stopping at 25m above surface
	LOCAL decentLex IS decent_math(shipThrust * 0.95).

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
	LOCAL decentLex IS decent_math(shipThrust * 0.95).

	LOCAL vSpeedTar IS MIN(0 - (ALT:RADAR - vertMargin - (ALT:RADAR * decentLex["stopTime"])) / (11 - decentLex["twr"]),- ABS(decentMinSpeed)).
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
CLEARVECDRAWS().
//SAS ON.

//end of core logic start of functions
FUNCTION decent_math {	// the math needed for sucide burn and fine decent
	PARAMETER shipThrust.
	LOCAL localGrav IS SHIP:BODY:MU/(SHIP:BODY:RADIUS + ALT:RADAR)^2.	//calculates gravity of the body
	LOCAL shipAcceleration IS shipThrust / SHIP:MASS.						//ship acceleration in m/s
	LOCAL stopTime IS  ABS(VERTICALSPEED) / (shipAcceleration - localGrav).//time needed to nutrlise vertical speed
	LOCAL stopDist IS 1/2 * shipAcceleration * stopTime * stopTime.			//how much distance is needed to come to a stop
	LOCAL twr IS MIN(shipAcceleration / localGrav, 10).					//the TWR of the craft based on local gravity
	RETURN LEX("stopTime",stopTime,"stopDist",stopDist,"twr",twr).
}

FUNCTION lowist_part {	//returns the largest dist from the root part for a part in the retrograde direction
	PARAMETER craft.
	LOCAL largest IS 0.
	FOR p IN craft:PARTS {
		LOCAL aft_dist IS VDOT(craft:ROOTPART:POSITION - p:POSITION, craft:FACING:FOREVECTOR).
		IF aft_dist < largest {
			SET  smallest TO aft_dist.
		}
	}
	RETURN largest.
}

FUNCTION chute_deploy {
	PARAMETER chuteTaged.
	IF SHIP:BODY:ATM:HEIGHT / 2 > SHIP:ALTITUDE {
		FOR chute IN SHIP:PARTSTAGGED(chuteTaged) {
			LOCAL moduleParachute IS chute:GETMODULE("moduleParachute").
			IF moduleParachute:HASFIELD("safe to deploy?") {
				IF moduleParachute:GETFIELD("safe to deploy?") = "Safe" {
					moduleParachute:SETFIELD("min pressure",0.01).
					moduleParachute:DOEVENT("deploy chute").
					SET chute:TAG TO "".
				}
			}
		}
	}
}

FUNCTION average_grav {
	PARAMETER rad1 IS SHIP:ALTITUDE,rad2 IS 0, localBody IS SHIP:BODY.
	IF rad1 > rad2 {
		RETURN ((localBody:MU / rad2) - (localBody:MU / rad1))/(rad1 - rad2).
	} ELSE IF rad2 > rad1 {
		RETURN ((localBody:MU / rad1) - (localBody:MU / rad2))/(rad2 - rad1).
	} ELSE {
		RETURN localBody:MU / rad1^2.
	}
}

FUNCTION when_triger {
	PARAMETER simPos,vertMargin.
	LOCAL stopPos IS SHIP:POSITION + simPos.
	RETURN (SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT) < vertMargin.
}

FUNCTION VecDrawAdd { // Draw the vector or update it.
	PARAMETER vecDrawLex,vecStart,vecTarget,localColour,localLabel,localScale,localWidth.

	IF vecDrawLex:KEYS:CONTAINS(localLabel) {
		SET vecDrawLex[localLabel]:START to vecStart.
		SET vecDrawLex[localLabel]:VEC to vecTarget.
		SET vecDrawLex[localLabel]:COLOUR to localColour.
		SET vecDrawLex[localLabel]:SCALE to localScale.
		SET vecDrawLex[localLabel]:WIDTH to localWidth.
	} ELSE {
		vecDrawLex:ADD(localLabel,VECDRAW(vecStart,vecTarget,localColour,localLabel,localScale,TRUE,localWidth)).
	}
}