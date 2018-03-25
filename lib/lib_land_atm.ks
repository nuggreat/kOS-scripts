FUNCTION sim_land_spot {//credit to dunbaratu for the orignal code
PARAMETER
ves,
isp,		//the isp of the active engines
dragCof,		//the cofecent of drag * area 
atmoDenc,	//the dencity of he atmosphere
tDelta,		//time step for sim
cruse.		//a cruse time with no thrust in seconds

LOCAL timeDelta IS MAX(tDelta,0.02).	//making it so the t_delta can't go below 0.02s
LOCAL GM IS ves:BODY:MU.				//the MU of the body the ship is in orbit of
LOCAL bodyPos IS ves:BODY:POSITION.	//the position of the body relitave to the ship
LOCAL thrustMax IS ves:AVAILABLETHRUST * 0.95.	//the thrust available to the ship
LOCAL m IS ves:MASS.					//the ship's mass
LOCAL vel IS ves:VELOCITY:SURFACE.	//the ship's velocity relitave to thesurface
LOCAL dragConstants IS dragCof * atmoDenc.
LOCAL preVel IS vel.
LOCAL deltaM IS (thrustMax / (9.806 * isp)) * timeDelta.//change in M per sec

LOCAL pos IS V(0,0,0).
LOCAL t IS 0.
LOCAL cycles IS 0.

IF cruse >= 0 {
UNTIL t >= cruse {	//advancses the simulation of the craft with out burning for the amount of time defined by cruse
	LOCAL upVec IS (pos - bodyPos).
	
//	LOCAL up_unit IS up_vec:NORMALIZED.
//	LOCAL localGrav IS GM / upVec:SQRMAGNITUDE.
//	LOCAL retroVec IS - vel:NORMALIZED.
//	LOCAL dragForce IS vel:SQRMAGNITUDE * dragConstants.
//	LOCAL dragAcc IS dragForce / m.
//	LOCAL accelVec IS (dragAcc * retroVec) - (localGrav * up_unit).
	LOCAL accelVec IS (((vel:SQRMAGNITUDE * dragConstants) / m) * (-vel:NORMALIZED)) - ((GM / upVec:SQRMAGNITUDE) * upVec:NORMALIZED).
	// above comented math is merged to save on IPU during the sim
	
	SET preVel TO vel.
	SET vel TO vel + (accelVec * timeDelta).
	
//	LOCAL avgVel IS (vel + preVel) / 2.
	
//	SET pos TO pos + (avgVel * timeDelta).
	SET pos TO pos + ((vel + preVel) / 2 * timeDelta).
	
	SET t TO t + timeDelta.
	SET cycles TO cycles + 1.
}}

UNTIL FALSE {	//retroburn simulation
	LOCAL upVec IS (pos - bodyPos).
	
	IF VDOT(vel, preVel) < 0 { BREAK. }	//ends sim when velosity reverses
	
//	LOCAL up_unit IS up_vec:NORMALIZED.
//	LOCAL localGrav IS GM / upVec:SQRMAGNITUDE.
//	LOCAL retroVec IS (- vel:NORMALIZED).
//	LOCAL dragForce IS vel:SQRMAGNITUDE * dragConstants.
//	LOCAL retroAcc IS ((dragForce + thrustMax) / m).
//	LOCAL accelVec IS (retroAcc * retroVec) - (up_unit * localGrav).
	LOCAL accelVec IS ((((vel:SQRMAGNITUDE * dragConstants) + thrustMax) / m) * (-vel:NORMALIZED)) - ((GM / upVec:SQRMAGNITUDE) * upVec:NORMALIZED).
	// above comented math is merged to save on IPU during the sim
	
	SET preVel TO vel.
	SET vel TO vel + (accelVec * timeDelta).
	
//	LOCAL avgVel is (vel + preVel) / 2.
	
//	SET pos TO pos + (avgVel * timeDelta).
	SET pos TO pos + (((vel + preVel) / 2) * timeDelta).
	SET m TO m - deltaM.
	
	IF m <= 0 { BREAK. }
	SET t TO t + timeDelta.
	SET cycles TO cycles + 1.
}

RETURN LEX("pos", pos,"vel", vel,"seconds", t,"mass", m,"cycles",cycles).
}

//FUNCTION atmo_pressure {//returns the perssure at a altitude in kPa using an aproximate calculation derived from the ksp wiki
//	PARAMETER localBody,//body that pressure data is needed for
//	craftAlt.//the height above sea level of the craft
//	IF craftAlt < 0 { SET craftAlt TO 0. }
//	IF localBody:ATM:HEIGHT > craftAlt { //values calculated with http://www.xuru.org/rt/TOC.asp
//		IF localBody = "kerbin" { RETURN 7.105.3029771 *CONSTANT:E^( -0.0001775474491 * craftAlt). }	//largest error of about  4 from true value
//		IF localBody = "duna" { RETURN 7.361071519 * CONSTANT:E^( -0.0001499584205 * craftAlt). }		//largest error of about  8 from true value
//		IF localBody = "layth" { RETURN 62.85397621 * CONSTANT:E^( -0.0001256495168 * craftAlt). }	//largest error of about 10 from true value
//		IF localBody = "eve" { RETURN 478.7532149 * CONSTANT:E^( -0.0001436822294 * craftAlt). }		//largest error of about 30 from true value
//		IF localBody = "jool" { RETURN 1503.850916 * CONSTANT:E^( -0.00002975714181 * craftAlt). }	//largest error of about 60 from true value
//	} ELSE { RETURN 0. }
//}