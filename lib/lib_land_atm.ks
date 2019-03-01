FUNCTION sim_land_atm {//credit to dunbaratu for the original code
PARAMETER
ves,
dragCof,		//the coefficient of drag * area / 2
molarMass,	//an approximation of the molar mass of the atmosphere (should be atm density divided by pressure)
tDelta,		//time step for sim
cruse,		//a cruse time with no thrust in seconds
throtCoef. //the reduction in throttle 

LOCAL localBody IS ves:BODY.
LOCAL localAtm IS localBody:ATM.
LOCAL timeDelta IS MAX(tDelta,0.02).	//making it so the t_delta can't go below 0.02s
LOCAL GM IS localBody:MU.				//the MU of the body the ship is in orbit of
LOCAL bodyPos IS localBody:POSITION.	//the position of the body relative to the ship
LOCAL thrustMax IS ves:AVAILABLETHRUST * throtCoef.	//the thrust available to the ship
LOCAL m IS ves:MASS.					//the ship's mass
LOCAL vel IS ves:VELOCITY:SURFACE.	//the ship's velocity relative to the surface
LOCAL preVel IS vel.
LOCAL deltaMcoef IS (timeDelta / 9.80665).
LOCAL activeEngs IS get_active_eng().
//LOCAL deltaM IS (thrustMax / isp) * deltaMcoef.//change in M per sec
LOCAL deltaM IS (thrustMax / (9.80665 * isp_calc())) * timeDelta.//change in M per sec
LOCAL vdLex IS LEX().
LOCAL seaLP IS (localAtm:ALTITUDEPRESSURE(0) * CONSTANT:ATMTOKPA) / 100.

LOCAL pos IS V(0,0,0).
LOCAL t IS 0.
LOCAL cycles IS 0.

IF cruse >= 0 {
UNTIL t >= cruse {	//advances the simulation of the craft with out burning for the amount of time defined by cruse
	LOCAL upVec IS (pos - bodyPos).

	LOCAL upUnit IS upVec:NORMALIZED.
	LOCAL localAlt IS upVec:MAG - localBody:RADIUS.
	LOCAL localPress IS localAtm:ALTITUDEPRESSURE(localAlt) * CONSTANT:ATMTOKPA.
	LOCAL localAtmDenc IS localPress * molarMass.
	LOCAL localGrav IS GM / upVec:SQRMAGNITUDE.
	LOCAL retroVec IS - vel:NORMALIZED.
	LOCAL dragForce IS (localAtmDenc * vel:SQRMAGNITUDE / 2) * dragCof.
	LOCAL dragAcc IS dragForce / m.
	LOCAL accelVec IS (dragAcc * retroVec) - (localGrav * upUnit).
	// above commented math is merged to save on IPU during the sim

	SET preVel TO vel.
	SET vel TO vel + (accelVec * timeDelta).

	SET pos TO pos + ((vel + preVel) / 2 * timeDelta).

	SET t TO t + timeDelta.
	SET cycles TO cycles + 1.
}}

UNTIL FALSE {	//retroburn simulation
	LOCAL upVec IS (pos - bodyPos).

	IF VDOT(vel, preVel) < 0 { BREAK. }	//ends sim when velocity reverses
	SET preVel TO vel.

	LOCAL upUnit IS upVec:NORMALIZED.
	LOCAL localAlt IS upVec:MAG - localBody:RADIUS.
	LOCAL localPress IS localAtm:ALTITUDEPRESSURE(localAlt) * CONSTANT:ATMTOKPA.
	LOCAL localThrust IS ves:AVAILABLETHRUSTAT(localPress * CONSTANT:KPATOATM) * throtCoef.
	LOCAL localAtmDenc IS localPress * molarMass.
	LOCAL localGrav IS GM / upVec:SQRMAGNITUDE.
	LOCAL retroVec IS - vel:NORMALIZED.
	LOCAL dragForce IS (localAtmDenc * vel:SQRMAGNITUDE / 2) * dragCof.
	LOCAL retroAcc IS ((dragForce + localThrust) / m).
	LOCAL accelVec IS (retroAcc * retroVec) - (upUnit * localGrav).
	//PRINT "df: " + ROUND(dragForce,2) + "         " AT(0,16).
	//PRINT "tf: " + ROUND(localThrust,2) + "         " AT(0,17).
	//PRINT "%slp: " + ROUND(localPress/seaLP,2) + "        " AT(0,18).
	//PRINT "%alt: " + ROUND(localAlt,2) + "        " AT(0,19).
	// above commented math is merged to save on IPU during the sim
	//VecDrawAdd(vdLex,SHIP:POSITION,((dragForce/m) * retroVec),RED,"dacc",1,1).
	//VecDrawAdd(vdLex,SHIP:POSITION,((localThrust/m) * retroVec),GREEN,"tacc",1,1).
	//VecDrawAdd(vdLex,SHIP:POSITION,pos,BLUE,"posVec",1,1).

	SET vel TO vel + (accelVec * timeDelta).

	SET pos TO pos + (((vel + preVel) / 2) * timeDelta).
	SET m TO m - deltaM.

	IF m <= 0 { BREAK. }
	SET t TO t + timeDelta.
	SET cycles TO cycles + 1.
}
CLEARVECDRAWS().
RETURN LEX("pos", pos,"vel", vel,"seconds", t,"mass", m,"cycles",cycles).
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

 //NOTE: Cd follows an exponential curve up to Mach 1, then jumps to 1/Mach maby