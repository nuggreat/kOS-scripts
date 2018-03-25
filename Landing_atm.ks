PARAMETER retroMargin IS 100.
FOR lib IN LIST("lib_land_atm","lib_navball2","lib_rocket_utilities") { IF EXISTS("1:/lib/" + lib + ".ksm") { RUNONCEPATH("1:/lib/" + lib + ".ksm"). } ELSE { RUNONCEPATH("1:/lib/" + lib + ".ks"). }}
control_point().
//LOCAL retroMargin IS 100.	//the distance above the gound that the ship will come to during the retroburn
LOCAL decentMinSpeed IS 0.5.//the slowest the craft will go on the hover decent
LOCAL chuteTag IS "chute".	//the tag for what parachutes are to be used
SAS OFF.
SET TERMINAL:WIDTH TO 60.
SET TERMINAL:HEIGHT TO 20.
WAIT UNTIL active_engine().
LOCK STEERING TO SHIP:SRFRETROGRADE.
LOCAL vertMargin IS lowist_part() + 7.5.	//Sets the margen for the Sucide Burn and Final Decent
LOCAL shipISP IS isp_calc().
LOCAL timePre IS TIME:SECONDS.
LOCAL tsMax IS 2.
LOCAL deltaTime IS 2.
LOCAL speedAtm IS SHIP:VELOCITY:SURFACE:MAG.
LOCAL speedVac IS VELOCITYAT(SHIP,(1 + timePre)):SURFACE:MAG.
LOCAL shipMass IS SHIP:MASS.
LOCAL dynamicP IS SHIP:Q.
LOCAL atmoDencity IS SHIP:Q / SHIP:VELOCITY:SURFACE:SQRMAGNITUDE.
LOCAL burnDV IS 0.
LOCAL dragForce IS 0.
LOCAL dragCofecent IS 0.
LOCAL stopGap IS 0.
LOCAL simLex IS LEX("seconds", 30).

//PID setup PIDLOOP(kP,kI,kD,min,max)
SET landing_PID TO PIDLOOP(0.5,0.1,0.05,0,1).
SET retroBurn_PID TO PIDLOOP(0.005,0.0005,0.0005,-1,0).
SET retroBurn_PID:SETPOINT TO retroMargin.

//start of core logic
LOCAL done IS FALSE.
UNTIL done {	//waiting until altitude deturmined by the sim is below the retroMargin
	WAIT 0.01.
	LOCAL timeS IS TIME:SECONDS.
	LOCAL initalMass IS SHIP:MASS.
	LOCAL shipPos IS SHIP:POSITION.
	SET dynamicP TO SHIP:Q.
	SET deltaTime TO (timeS - timePre + deltaTime) / 2.
	SET tsMax TO (tsMax + (simLex["seconds"]/10)) / 2.
	SET timePre TO timeS.
	IF SHIP:BODY:ATM:EXISTS AND dynamicP > 0 {
		SET speedVac TO VELOCITYAT(SHIP,(deltaTime + timeS)):SURFACE:MAG.
		SET atmoDencity TO (dynamicP * 2) / SHIP:VELOCITY:SURFACE:SQRMAGNITUDE.
		SET shipISP TO isp_calc().
		SET simLex TO sim_land_spot(SHIP,shipISP,dragCofecent,atmoDencity,MIN(deltaTime,tsMax),deltaTime).
		SET burnDV TO shipISP * 9.806 * LN(initalMass / SHIP:MASS).
		SET speedAtm TO SHIP:VELOCITY:SURFACE:MAG.
		SET dragForce TO ((speedVac - (speedAtm + burnDV)) / deltaTime) * initalMass.
		SET dragCofecent TO (dragForce / MAX(dynamicP,0.0001) + dragCofecent) / 2.
		chute_deploy(chuteTag).
		CLEARSCREEN.
		PRINT "drag Force:  " + ROUND(dragForce,2).
	} ELSE {
		SET simLex TO sim_land_spot(SHIP,shipISP,0,0,MIN(deltaTime,simLex["seconds"]/10),deltaTime).
		CLEARSCREEN.
		SET speedAtm TO SHIP:VELOCITY:SURFACE:MAG.
	}
	LOCAL stopPos IS shipPos + simLex["pos"].
	SET stopGap TO SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT.
	PRINT "Terrain gap: " + ROUND(stopGap).
	PRINT "Dv needed:   " + ROUND(shipISP*9.806*LN(initalMass/simLex["mass"])).
	PRINT "Speed:       " + ROUND(speedAtm,1).
	PRINT " ".
	PRINT "time to stop: " + ROUND(simLex["seconds"],2).
	PRINT "Time Per Sim: " + ROUND(deltaTime,2).
	PRINT "Steps Per Sim: " + simLex["cycles"].
	SET done TO stopGap < retroMargin.
}
GEAR ON.
LIGHTS ON.
LOCK STEERING TO SHIP:SRFRETROGRADE.

LOCAL throttDamper IS retroBurn_PID:UPDATE(TIME:SECONDS,stopGap).
LOCK THROTTLE TO MAX(1 + throttDamper,0.75). //remove max latter
LOCAL done IS FALSE.
UNTIL done {	//retrograde burn until vertical speed is greater than -2
	WAIT 0.01.
	LOCAL timeS IS TIME:SECONDS.
	LOCAL initalMass IS SHIP:MASS.
	LOCAL shipPos IS SHIP:POSITION.
	SET dynamicP TO SHIP:Q.
	SET deltaTime TO (timeS - timePre + deltaTime) / 2.
	SET tsMax TO (tsMax + (simLex["seconds"]/10)) / 2.
	SET timePre TO timeS.
	IF SHIP:BODY:ATM:EXISTS {
		SET speedVac TO VELOCITYAT(SHIP,(deltaTime + timeS)):SURFACE:MAG.
		SET atmoDencity TO (dynamicP * 2) / SHIP:VELOCITY:SURFACE:SQRMAGNITUDE.
		SET shipISP TO isp_calc().
		SET simLex TO sim_land_spot(SHIP,shipISP,dragCofecent,atmoDencity,MIN(deltaTime,tsMax),0).
		SET burnDV TO shipISP * 9.806 * LN(initalMass / SHIP:MASS).
		SET speedAtm TO SHIP:VELOCITY:SURFACE:MAG.
		SET dragForce TO ((speedVac - (speedAtm + burnDV)) / deltaTime) * initalMass.
		SET dragCofecent TO (dragForce / MAX(dynamicP,0.0001) + dragCofecent) / 2.
		chute_deploy(chuteTag).
		CLEARSCREEN.
		PRINT "drag Force:  " + ROUND(dragForce,2).
	} ELSE {
		SET simLex TO sim_land_spot(SHIP,shipISP,0,0,MIN(deltaTime,simLex["seconds"]/10),0).
		CLEARSCREEN.
		SET speedAtm TO SHIP:VELOCITY:SURFACE:MAG.
	}
	LOCAL stopPos IS shipPos + simLex["pos"].
	SET stopGap TO SHIP:BODY:ALTITUDEOF(stopPos) - SHIP:BODY:GEOPOSITIONOF(stopPos):TERRAINHEIGHT.
	SET throttDamper TO retroBurn_PID:UPDATE(TIME:SECONDS,stopGap).
	PRINT "Terrain gap: " + ROUND(stopGap).
	PRINT "Dv needed:   " + ROUND(shipISP*9.806*LN(initalMass/simLex["mass"])).
	PRINT "Speed:       " + ROUND(speedAtm,1).
	PRINT " ".
	PRINT "time to stop: " + ROUND(simLex["seconds"],2).
	PRINT "Time Per Sim: " + ROUND(deltaTime,2).
	PRINT "Steps Per Sim: " + simLex["cycles"].
	SET done TO VERTICALSPEED > -2 AND GROUNDSPEED < 10.
}
UNLOCK THROTTLE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

LOCAL shipThrust IS SHIP:AVAILABLETHRUST.
LOCAL sucideMargin IS vertMargin + 10.
SET landing_PID:SETPOINT TO sucideMargin - 0.1.
LOCAL done IS FALSE.
UNTIL done {	//sucide burn stotoping at 25m above surface
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

FUNCTION lowist_part {	//returns the largist dist from the COM for a part in the retrograde direction
	LOCAL biggest IS 0.
	LOCAL aft_unit IS (-1)*SHIP:FACING:FOREVECTOR. // unit vec in aft direction.
	FOR p IN SHIP:PARTS {
		LOCAL aft_dist IS VDOT(p:POSITION, aft_unit). // distance in terms of aft-ness.
		IF aft_dist > biggest {
			SET  biggest TO aft_dist.
		}
	}
	RETURN biggest.
}

FUNCTION chute_deploy {
	PARAMETER chuteTaged.
	IF SHIP:BODY:ATM:HEIGHT / 2 > SHIP:ALTITUDE {
		FOR chute IN SHIP:PARTSTAGGED(chuteTaged) {
			LOCAL moduleParachure IS chute:GETMODULE("moduleParachute").
			IF moduleParachure:HASFIELD("safe to deploy?") {
				IF moduleParachure:GETFIELD("safe to deploy?") = "Safe" {
					moduleParachure:SETFIELD("min pressure",0.01).
					moduleParachure:DOEVENT("deploy chute").
					SET chute:TAG TO "".
				}
			}
		}
	}
}