//velocity vector and radius to eccentricity.

//LOCAL bodyMu IS BODY:MU.
//
////v^2/b - 1/r = v^2 - b/r
//
//LOCAL radVec IS UP:VECTOR * BODY:RADIUS.
//LOCAL circVel IS SQRT(bodyMu / radVec:MAG).
//LOCAL tgtVel IS circVel - 100.
//LOCAL velVec IS UP:VECTOR * tgtVel.
//SET velVec TO ANGLEAXIS(90,SHIP:NORTH:VECTOR) * velVec.
//
//SET radVec TO SHIP:POSITION - SHIP:BODY:POSITION.
//SET velVec TO SHIP:VELOCITY:ORBIT.
//PRINT SHIP:ORBIT:ECCENTRICITY.
//
//LOCAL ecc1 IS (((velVec:SQRMAGNITUDE - bodyMu / radVec:MAG) * radVec - VDOT(radVec,velVec) * velVec) / bodyMu):MAG.
//PRINT ecc1.
//
//LOCAL ecc2 IS (((velVec:SQRMAGNITUDE / bodyMu - 1/radVec:MAG) * radVec - VDOT(radVec,velVec) / bodyMu * velVec)):MAG.
//PRINT ecc2.
//
//LOCAL zenith IS VANG(UP:VECTOR,velVec:NORMALIZED).//angle from strait up
//LOCAL ecc3 IS SQRT(((radVec:MAG * velVec:SQRMAGNITUDE / bodyMu - 1)^2 * SIN(zenith)^2 + COS(zenith)^2)).
//PRINT ecc3.
//
//LOCAL zenith IS 90 - VANG(UP:VECTOR,velVec:NORMALIZED).//angle above/below the horizon of velocity vector
//LOCAL ecc4 IS SQRT(((radVec:MAG * velVec:SQRMAGNITUDE / bodyMu - 1)^2 * COS(zenith)^2 + SIN(zenith)^2)).
//PRINT ecc4.
//
//LOCAL sma IS 1 / (2 / radVec:MAG - velVec:SQRMAGNITUDE / bodyMu).
//PRINT sma.
//PRINT SHIP:ORBIT:SEMIMAJORAXIS.

LOCAL logPathBase IS "0:/logs/".
LOCAL allBodies IS list_all_child_bodies().
SET CONFIG:IPU TO 2000.
LOCAL bodiesDone IS 0.
SET skip TO 0.
FOR localBody IN allBodies {
	PRINT bodiesDone / (allBodies:LENGTH - 1).
	PRINT localBody:NAME.
	IF localBody:HASSOLIDSURFACE  AND skip <= bodiesDone {
		LOCAL bodyMu IS localBody:MU.
		LOCAL rad IS localBody:RADIUS.
		LOCAL logPathLocal IS logPathBase + localBody:NAME + ".CSV".
		IF EXISTS(logPathLocal) {
			DELETEPATH(logPathLocal).
		}
		LOG ("bodyRad," + rad + ",bodyMu," + bodyMu + ",obtVel," + SQRT(bodyMU / rad)) TO logPathLocal.
		LOG "degDist,launchPitch,launchVel" TO logPathLocal.

		LOCAL vel IS 1.
		LOCAL done IS FALSE.
		UNTIL done {
			LOCAL degResults IS deg_around_for@:BIND(bodyMu,rad,vel).
			LOCAL angResult IS ternary_search(degResults@,1,89,0.001).
			LOCAL degAround IS degResults(angResult).
			LOG (degAround + "," + angResult + "," + vel) TO logPathLocal.
			IF degAround > 180 {
				SET done TO TRUE.
			}
			SET vel TO ROUND(vel + 0.1,1).
		}
	}
	SET bodiesDone TO bodiesDone + 1.
}
SET CONFIG:IPU TO 200.

FUNCTION deg_around_for {
	PARAMETER bodyMu,rad,vel,lPitch.
	LOCAL obtElements IS obt_elements(bodyMu,rad,vel,lPitch).
	LOCAL taOfRad IS ARCCOS((-obtElements["sma"] * obtElements["ecc"]^2 + obtElements["sma"] - rad) / (obtElements["ecc"] * rad)).
	RETURN (180 - taOfRad) * 2.
}

FUNCTION obt_elements {
	PARAMETER bodyMu,// is BODY:MU
	rad,//distance from center of body to vessel position
	vel,//magnitude of velocity vector
	lPitch.//pitch from the horizon of the velocity vector
	LOCAL velSqr IS vel^2.
	LOCAL ecc IS SQRT((rad * velSqr / bodyMu - 1)^2 * COS(lPitch)^2 + SIN(lPitch)^2).
	LOCAL sma IS 1/(2 / rad - velSqr / bodyMu).
	RETURN LEX("ecc",ecc,"sma",sma).
}

FUNCTION ternary_search {
	PARAMETER f, left, right, absPrecision.
	UNTIL FALSE {
		IF ABS(right - left) < absPrecision {
			RETURN (left + right) / 2.
		}
		LOCAL leftThird IS left + (right - left) / 3.
		LOCAL rightThird IS right - (right - left) / 3.
		IF f(leftThird) < f(rightThird) {
			SET left TO leftThird.
		} ELSE {
			SET right TO rightThird.
		}
	}
}

FUNCTION list_all_child_bodies{
	PARAMETER parentBody IS SUN.
	LOCAL returnList IS LIST().
	FOR childBody IN parentBody:ORBITINGCHILDREN {
		returnList:ADD(childBody).
		FOR grandChild IN list_all_child_bodies(childBody) {
			returnList:ADD(grandChild).
		}
	}
	RETURN returnList.
}


//r = rad
//m = bodyMu
//v = velSqr
//p = lPitch
//
//cos((45-p)*4) = (-(1/(2 / r - v / m)) * ((r * v / m - 1)^2 * COS(p)^2 + SIN(p)^2) + (1/(2 / r - v / m)) - r) / (SQRT((r * v / m - 1)^2 * COS(p)^2 + SIN(p)^2) * r)
//
//
//}
//
//
//r = rad
//m = bodyMu
//v = velSqr
//p = lPitch
//
//SQRT((r * v^2 / m - 1)^2 * COS(p)^2 + SIN(p)^2) solve for v

//c = SQRT((r * v / m - 1)^2 * COS(p)^2 + SIN(p)^2), s = 1/(2 / r - v / m), d = ARCCOS((s * c^2 + s - r) / (c * r)) solve for v