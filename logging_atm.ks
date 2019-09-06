LOCAL logCount IS 0.
LOCAL localBody IS SHIP:BODY.
LOCAL localAtm IS localBody:ATM.
UNTIL NOT EXISTS(PATH("0:/logs/atm_log_" + logCount + ".csv")) {
	SET logCount TO logCount + 1.
}
LOCAL logPath IS PATH("0:/logs/atm_log_" + logCount + ".csv").
PRINT "logging to " + logPath.
LOG ("time(s),altitude(m),vel(m/s),Q(kPa),force(kN),press(kPa),atmDencity(kg/m^3),dragCoef(m^2),mg/J,temp(K),mach(m/s),body: " + localBody:NAME) TO logPath.


LOCAL jPerKgK IS (8.3144598/0.00042).//this is ideal gas constant dived by the molecular mass of the bodies atmosphere
LOCAL heatCapacityRatio IS 1.2.
IF localBody = KERBIN {
	SET jPerKgK TO (8.3144598/0.0289644).
	SET heatCapacityRatio TO 1.4.
	PRINT "local Body is Kerbin".
}

WAIT UNTIL ALTITUDE < SHIP:BODY:ATM:HEIGHT * 0.9.

LOCAL preVel IS SHIP:VELOCITY:SURFACE.
LOCAL preTime IS TIME:SECONDS.
LOCAL preGravVec IS localBody:POSITION - SHIP:POSITION.
LOCAL preForeVec IS SHIP:FACING:FOREVECTOR.
LOCAL preMass IS SHIP:MASS.
LOCAL preDynamicP IS SHIP:Q * CONSTANT:ATMTOKPA.
LOCAL preAtmPressure IS MAX(localAtm:ALTITUDEPRESSURE(ALTITUDE) * CONSTANT:ATMTOKPA,0.000001).
LOCAL atmDencity IS (preDynamicP * 2) / preVel:SQRMAGNITUDE.
LOCAL atmMolarMass IS atmDencity / preAtmPressure.

LOCAL burnCoeff IS 0.
IF active_engine { SET burnCoeff TO 1.}
SET CONFIG:IPU TO 2000.

LOCAL timeNext IS TIME:SECONDS + 0.5.
RCS OFF.
UNTIL RCS {
	//WAIT UNTIL timeNext <= TIME:SECONDS.
	WAIT 0.

	LOCAL newTime IS TIME:SECONDS.
	LOCAL newAlt IS SHIP:ALTITUDE.
	LOCAL newDynamicP IS SHIP:Q.//is in atmospheres 
	LOCAL newVel IS SHIP:VELOCITY:SURFACE.
	LOCAL newAtmPressure IS MAX(localAtm:ALTITUDEPRESSURE(newAlt),0.0000001).
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
	LOCAL burnDV IS shipISP * 9.80665 * LN(preMass / newMass) * burnCoeff.
	LOCAL accelVec IS avrForeVec * burnDV.
	LOCAL dragAcc IS (newVel - (preVel + gravVec + accelVec)) / deltaTime.
	LOCAL dragForce IS ((newMass + preMass) / 2) * VDOT(dragAcc,avrForeVec).
	SET atmDencity TO (avrDynamicP * 2) / ((newVel:SQRMAGNITUDE + preVel:SQRMAGNITUDE) / 2).//derived from q = d * v^2 / 2
	SET dragCoef TO dragForce / MAX(avrDynamicP,0.0001).
	SET thermalMassIsh TO atmDencity / avrPressure.
	LOCAL atmTemp IS avrPressure / (jPerKgK * atmDencity).
	LOCAL mach IS SQRT(heatCapacityRatio * jPerKgK * atmTemp).
	CLEARSCREEN.
	PRINT "pres: " + newAtmPressure.
	PRINT "denc: " + atmDencity * 1000.
	PRINT "temp: " + atmTemp.
	PRINT "mach: " + mach.
	PRINT "dCof: " + dragCoef.
	PRINT "forc: " + dragForce.
	log_data(LIST(newTime,newAlt,newVel:MAG,newDynamicP,dragForce,newAtmPressure,atmDencity*1000,dragCoef,thermalMassIsh,atmTemp,mach),logPath).

	SET preVel TO newVel.
	SET preTime TO newTime.
	SET preGravVec TO newGravVec.
	SET preForeVec TO newForeVec.
	SET preMass TO newMass.
	SET preDynamicP TO newDynamicP.
	SET preAtmPressure TO newAtmPressure.
	SET timeNext TO timeNext + 0.5.
	PRINT "delta time: " + ROUND(TIME:SECONDS - newTime,2).
}

FUNCTION log_data {
	PARAMETER logData,logPath.
	LOCAL logString IS "".
	FOR data IN logData {
		SET logString TO logString + data + ",".
	}
	logString:REMOVE((logString:LENGTH - 1),1).
	LOG logString TO logPath.
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

FUNCTION get_active_eng {
	LOCAL engList IS LIST().
	LIST ENGINES IN engList.
	LOCAL returnList IS LIST().
	FOR eng IN engList {
		IF eng:IGNITION AND NOT eng:FLAMEOUT {
			returnList:ADD(eng).
		}
	}
	RETURN returnList.
}

FUNCTION isp_at {
	PARAMETER engineList,curentPressure.//curentPressure should be in KpA
	SET curentPressure TO curentPressure * CONSTANT:KPATOATM.
	LOCAL totalFlow IS 0.
	LOCAL totalThrust IS 0.
	FOR engine IN engineList {
		LOCAL engThrust IS engine:AVAILABLETHRUSTAT(curentPressure).
		SET totalFlow TO totalFlow + (engThrust / (engine:ISPAT(curentPressure) * 9.80665)).
		SET totalThrust TO totalThrust + engThrust.
	}
	IF totalThrust = 0 {
		RETURN 1.
	}
	RETURN (totalThrust / (totalFlow * 9.80665)).
}

FUNCTION active_engine { // check for a active engine on ship
	PARAMETER doPrint IS TRUE.
	LOCAL engineList IS LIST().
	LIST ENGINES IN engineList.
	LOCAL haveEngine IS FALSE.
	FOR engine IN engineList {
		IF engine:IGNITION AND NOT engine:FLAMEOUT {
			SET haveEngine TO TRUE.
			BREAK.
		}
	}
	IF haveEngine AND doPrint {
		CLEARSCREEN.
		PRINT "Active Engine Found.".
	} ELSE IF NOT haveEngine {
		CLEARSCREEN.
		PRINT "No Active Engines Found.".
	}
	WAIT 0.1.
	RETURN haveEngine.
}