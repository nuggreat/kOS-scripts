FUNCTION VecDrawAdd { // Draw the vector or update it.
	PARAMETER vecDrawLex,vecStart,vecTarget,localColour,localLabel,localScale.
	
	IF vecDrawLex:KEYS:CONTAINS(localLabel) {
		SET vecDrawLex[localLabel]:START to vecStart.
		SET vecDrawLex[localLabel]:VEC to vecTarget.
		SET vecDrawLex[localLabel]:COLOUR to localColour.
		SET vecDrawLex[localLabel]:SCALE to localScale.
	} ELSE {
		vecDrawLex:ADD(localLabel,VECDRAW(vecStart,vecTarget,localColour,localLabel,localScale,TRUE,0.2)).
	}
}

FUNCTION accel_data { //using the Accelerometer part returns the current acceleration of the SHIP in m/s
	LOCAL accelPart IS SHIP:PARTSNAMED("sensorAccelerometer").
	IF accelPart:LENGTH > 0 {
		LOCAL accelModule IS accelPart[0]:GETMODULE("moduleenvirosensor").
		LOCAL accelData IS accelModule:GETFIELD("display").
		IF accelData = "off" {
			accelModule:DOEVENT("toggle display").
			WAIT 0.
			SET accelData TO accelModule:GETFIELD("display").
		}
		SET accelData TO accelData:SUBSTRING(0,accelData:LENGTH - 2):TONUMBER(0) * 9.80665.
		RETURN accelData.
	} ELSE {
		RETURN 0.
	}
}

FUNCTION advanced_heading {//works just like HEADING but lets you set the roll
	PARAMETER myHeading,myPitch,myRoll.
	LOCAL returnDir IS HEADING(myHeading,myPitch).
	RETURN ANGLEAXIS(myRoll,returnDir:FOREVECTOR) * returnDir.
}

FUNCTION pseudo_throttle {
	PARAMETER throt, tConfig.  //tConfig LIST(LIST(triger level for engine set, list of engines to cycle))
	FOR data IN tConfig {
		IF throt > data[0] {
			FOR eng IN data[1] { eng:ACTIVATE(). }
		} ELSE {
			FOR eng IN data[1] { eng:SHUTDOWN(). }
		}
	}
}

FUNCTION pseudo_throttle_config { //creates config file for pseudo_throttle
	PARAMETER tagHeader IS "eng", symetry IS 2.
	LOCAL numberPairs IS SHIP:PARTSTAGGEDPATTERN(tagHeader):LENGTH / symetry + 1.
	LOCAL tConfig IS LIST().
	FROM { LOCAL i IS numberPairs - 2. } UNTIL 0 > i STEP { SET i TO i - 1. } DO {
		tConfig:ADD(LIST((i + 1) / numberPairs,SHIP:PARTSTAGGED(tagHeader + i))).
	}
	RETURN tConfig.
}

FUNCTION altitude_to_time { //returns the UT in seconds of when the orbit reaches the given altitude, returns -1 when target altitude is above/below orbit
	PARAMETER targetAltitude.
	
	LOCAL returnTime IS -1.
	IF targetAltitude < SHIP:ORBIT:APOAPSIS AND targetAltitude > SHIP:ORBIT:PERIAPSIS {
	
		LOCAL localBody IS SHIP:BODY.
		LOCAL highPoint IS ETA:APOAPSIS + TIME:SECONDS.
		LOCAL lowPoint IS ETA:PERIAPSIS + TIME:SECONDS.
		
		IF SHIP:ALTITUDE < targetAltitude AND SHIP:VERTICALSPEED > 0 {
			SET lowPoint TO TIME:SECONDS.
		} ELSE IF SHIP:ALTITUDE > targetAltitude AND SHIP:VERTICALSPEED < 0 {
			SET highPoint TO TIME:SECONDS.
		}
		
		LOCAL midPoint IS (lowPoint + highPoint) / 2.
		LOCAL midPointAlt IS localBody:ALTITUDEOF(POSITIONAT(SHIP,midPoint)) - targetAltitude.
		UNTIL ABS(midPointAlt) < 1 {
			IF midPointAlt > 0 {
				SET highPoint TO midPoint.
			} ELSE {
				SET lowPoint TO midPoint.
			}
			SET midPoint TO (lowPoint + highPoint) / 2.
			SET midPointAlt TO localBody:ALTITUDEOF(POSITIONAT(SHIP,midPoint)) - targetAltitude.
		}
		SET returnTime TO midPoint.
	}
	RETURN returnTime.
}

FUNCTION burn_along_vector {//needs libs formating, rocker utilities
	PARAMETER DVvector,startTime IS TIME:SECONDS,doStage IS TRUE.
	ABORT OFF.
	LOCAL timePast IS TIME:SECONDS.
	LOCAL potentialAccel IS SHIP:AVAILABLETHRUST / SHIP:MASS.
	LOCAL shipISP IS isp_calc().
	LOCAL count IS 5.

	LOCK STEERING TO DVvector.
	WAIT UNTIL (ABS(STEERINGMANAGER:ANGLEERROR) < 0.1) AND (startTime <= TIME:SECONDS).//wait until within 0.1 degrees of target
	LOCK THROTTLE TO MAX(MIN(DVvector:MAG / (potentialAccel * 1),1),0.01).
	CLEARSCREEN.
	UNTIL DVvector:MAG < 0.01 OR ABORT {	//executing the burn
		WAIT 0.
		SET potentialAccel TO SHIP:AVAILABLETHRUST / SHIP:MASS.
		LOCAL timeNow IS TIME:SECONDS.
		LOCAL throt IS THROTTLE.
		LOCAL shipFacingFore IS SHIP:FACING:FOREVECTOR.

		LOCAL deltaTime IS timeNow - timePast.
		SET timePast TO timeNow.
		LOCAL shipAcceleration IS (potentialAccel * throt * deltaTime).
		SET DVvector TO DVvector - (shipAcceleration * shipFacingFore).

		IF count >= 5 {
			PRINT " DeltaV left on burn:" + padding(DVvector:MAG,1,1) + "m/s      " AT(0,0).
			PRINT "   Time left on burn:" + time_converter(burn_duration(shipISP,DVvector:MAG),1) + "      " AT(0,1).
			SET count TO 0.
		} ELSE {
			SET count TO count + 1.
		}

		IF stage_check(doStage) { SET shipISP TO isp_calc(). }//if i stage recalculate the ISP
	}
}