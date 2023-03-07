LOCAL logCount TO 0.
LOCAL localBody TO SHIP:BODY.
LOCAL localAtm TO localBody:ATM.
UNTIL NOT EXISTS(PATH("0:/logs/atm_log_" + logCount + ".csv")) {
	SET logCount TO logCount + 1.
}
LOCAL logPath TO PATH("0:/logs/atm_log_" + logCount + ".csv").
PRINT "logging to " + logPath.
LOG ("time(s),altitude(m),vel(m/s),Q(kPa),force(kN),press(kPa),atmDencity(kg/m^3),dragCoef(m^2),mg/J,temp(K),mach(m/s),body: " + localBody:NAME) TO logPath.


LOCAL jPerKgK TO CONSTANT:IDEALGAS() / localAtm:MOLARMASS.//this is ideal gas constant dived by the molecular mass of the bodies atmosphere
LOCAL heatCapacityRatio TO localAtm:ADIABATICINDEX.

WAIT UNTIL ALTITUDE < SHIP:BODY:ATM:HEIGHT * 0.9.

LOCAL preVel TO SHIP:VELOCITY:SURFACE.
LOCAL preTime TO TIME:SECONDS.
LOCAL preGravVec TO localBody:POSITION - SHIP:POSITION.
LOCAL preForeVec TO SHIP:FACING:FOREVECTOR.
LOCAL preMass TO SHIP:MASS.
LOCAL preDynamicP TO SHIP:Q * CONSTANT:ATMTOKPA.
LOCAL preAtmPressure TO MAX(localAtm:ALTITUDEPRESSURE(ALTITUDE) * CONSTANT:ATMTOKPA,0.000001).
LOCAL atmDencity TO (preDynamicP * 2) / preVel:SQRMAGNITUDE.
LOCAL atmMolarMass TO atmDencity / preAtmPressure.

LOCAL burnCoeff TO 0.
IF active_engine { SET burnCoeff TO 1.}
SET CONFIG:IPU TO 2000.

LOCAL timeNext TO TIME:SECONDS + 0.5.
RCS OFF.
UNTIL RCS {
	//WAIT UNTIL timeNext <= TIME:SECONDS.
	WAIT 0.

	LOCAL newTime TO TIME:SECONDS.
	LOCAL newAlt TO SHIP:ALTITUDE.
	LOCAL newDynamicP TO SHIP:Q.//is in atmospheres 
	LOCAL newVel TO SHIP:VELOCITY:SURFACE.
	LOCAL newAtmPressure TO MAX(localAtm:ALTITUDEPRESSURE(newAlt),0.0000001).
	LOCAL newMass TO SHIP:MASS.
	LOCAL newForeVec TO SHIP:FACING:FOREVECTOR.
	LOCAL newGravVec TO localBody:POSITION - SHIP:POSITION.

	SET newAtmPressure TO newAtmPressure * CONSTANT:ATMTOKPA.
	SET newDynamicP TO newDynamicP * CONSTANT:ATMTOKPA.
	//SET newMass TO newMass * 1000.

	LOCAL avrPressure TO (newAtmPressure + preAtmPressure) / 2.
	LOCAL avrDynamicP TO (newDynamicP + preDynamicP) / 2.
	LOCAL avrForeVec TO ((newForeVec + preForeVec) / 2):NORMALIZED.
	SET shipISP TO isp_at(get_active_eng(),avrPressure).

	LOCAL deltaTime TO newTime - preTime.
	LOCAL gravVec TO average_grav(newGravVec:MAG,newGravVec:MAG) * (newGravVec:NORMALIZED + preGravVec:NORMALIZED):NORMALIZED * deltaTime.
	LOCAL burnDV TO shipISP * 9.80665 * LN(preMass / newMass) * burnCoeff.
	LOCAL accelVec TO avrForeVec * burnDV.
	LOCAL dragAcc TO (newVel - (preVel + gravVec + accelVec)) / deltaTime.
	LOCAL dragForce TO ((newMass + preMass) / 2) * VDOT(dragAcc,avrForeVec).
	SET atmDencity TO (avrDynamicP * 2) / ((newVel:SQRMAGNITUDE + preVel:SQRMAGNITUDE) / 2).//derived from q = d * v^2 / 2
	SET dragCoef TO dragForce / MAX(avrDynamicP,0.0001).
	SET thermalMassIsh TO atmDencity / avrPressure.
	LOCAL atmTemp TO avrPressure / (jPerKgK * atmDencity).
	LOCAL mach TO SQRT(heatCapacityRatio * jPerKgK * atmTemp).
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
	LOG logData:JOIN(",") TO logPath.
}

FUNCTION average_grav {
	PARAMETER rad1 TO SHIP:ALTITUDE,rad2 TO 0, localBody TO SHIP:BODY.
	IF rad1 > rad2 {
		RETURN ((localBody:MU / rad2) - (localBody:MU / rad1))/(rad1 - rad2).
	} ELSE IF rad2 > rad1 {
		RETURN ((localBody:MU / rad1) - (localBody:MU / rad2))/(rad2 - rad1).
	} ELSE {
		RETURN localBody:MU / rad1^2.
	}
}

FUNCTION get_active_eng {
	LOCAL engList TO LIST().
	LIST ENGINES IN engList.
	LOCAL returnList TO LIST().
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
	LOCAL totalFlow TO 0.
	LOCAL totalThrust TO 0.
	FOR engine IN engineList {
		LOCAL engThrust TO engine:AVAILABLETHRUSTAT(curentPressure).
		SET totalFlow TO totalFlow + (engThrust / (engine:ISPAT(curentPressure) * 9.80665)).
		SET totalThrust TO totalThrust + engThrust.
	}
	IF totalThrust = 0 {
		RETURN 1.
	}
	RETURN (totalThrust / (totalFlow * 9.80665)).
}

FUNCTION active_engine { // check for a active engine on ship
	PARAMETER doPrint TO TRUE.
	LOCAL engineList TO SHIP:ENGINES.
	LOCAL haveEngine TO FALSE.
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