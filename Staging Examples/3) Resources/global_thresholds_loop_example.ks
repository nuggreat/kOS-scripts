LOCAL targetAP IS 80_000.
LOCAL initalPitch IS 20.
LOCAL vMax IS 200.
LOCAL bodyRad IS BODY:RADIUS.
LOCAL bodyMu IS BODY:MU.
LOCAL orbitTransition IS BODY:ATM:HEIGHT.

FROM { LOCAL i IS -5. } UNTIL i >= 0 STEP { SET i TO i + 1. } DO {
  PRINT "t" + i.
  WAIT 1.
}
LOCAL tarPitch IS 90.
LOCAL throt IS 1.
LOCK STEERING TO HEADING(90,tarPitch).
LOCK THROTTLE TO MAX(MIN(CHOOSE throt IF throt > 0.01 ELSE 0,1),0).
LOCAL stagingStruct IS staging_start(LIST(
  "stage",0,
  "liquidFuel",7200,
  "liquidFuel",6120,
  "liquidFuel",5040,
  "liquidFuel",720.01,
  "stage",0
)).

PRINT "initial pitch maneuver".
UNTIL VERTICALSPEED > vMax AND VANG(SRFPROGRADE:VECTOR,UP:VECTOR) > initalPitch {
  SET tarPitch TO 90 - MAX(MIN(VERTICALSPEED / vMax,initalPitch) * initalPitch,0).
  LOCAL currentAcc IS MAX(SHIP:AVAILABLETHRUST,0.001) / SHIP:MASS.
  LOCAL desiredSpeed IS speed_given_ap(ALTITUDE + bodyRad, targetAP).
  SET throt TO ((desiredSpeed - SHIP:VELOCITY:ORBIT:MAG) / currentAcc).
  staging_check(stagingStruct).
  WAIT 0.
}

PRINT "surface prograde follow".
LOCK STEERING TO SRFPROGRADE.
UNTIL ALTITUDE > orbitTransition {
  LOCAL currentAcc IS MAX(SHIP:AVAILABLETHRUST,0.001) / SHIP:MASS.
  LOCAL desiredSpeed IS speed_given_ap(ALTITUDE + bodyRad, targetAP).
  SET throt TO ((desiredSpeed - SHIP:VELOCITY:ORBIT:MAG) / currentAcc).
  staging_check(stagingStruct).
  WAIT 0.
}

PRINT "circularizing orbit".
LOCK STEERING TO PROGRADE.
UNTIL PERIAPSIS > targetAP - 250 {
  LOCAL currentAcc IS MAX(SHIP:AVAILABLETHRUST,0.001) / SHIP:MASS.
  LOCAL desiredSpeed IS SQRT(bodyMu / (APOAPSIS + bodyRad)).
  SET throt TO ((desiredSpeed - SHIP:VELOCITY:ORBIT:MAG) / currentAcc) - signed_eta_ap() + 1.
  staging_check(stagingStruct).
  WAIT 0.
}
UNLOCK THROTTLE.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
PRINT "Space!".

FUNCTION speed_given_ap {
  PARAMETER currentRad,ap.
  LOCAL sma IS (PERIAPSIS + ap) / 2 + bodyRad.
  RETURN SQRT((bodyMu * (2 * sma - currentRad)) / (sma * currentRad)).
}

FUNCTION signed_eta_ap {
  IF ETA:APOAPSIS < ETA:PERIAPSIS {
    RETURN ETA:APOAPSIS.
  } ELSE {
    RETURN -ETA:APOAPSIS.
  }
}

FUNCTION staging_start {
  PARAMETER sequenceList.
  LOCAL sequenceData IS LIST().
  FROM { LOCAL i IS 0. } UNTIL (i >= sequenceList:LENGTH) STEP { SET i TO i + 2. } DO {
    sequenceData:ADD(sequenceList[0 + i]).
    sequenceData:ADD(MAX(sequenceList[1 + i],0)).
  }
  SET sequenceData[0] TO get_resource(sequenceData[0]).
  RETURN sequenceData.
}

FUNCTION staging_check {
  PARAMETER sequenceData.
  IF STAGE:READY AND (sequenceData:LENGTH > 0) {
    IF sequenceData[0]:AMOUNT <= sequenceData[1] {
      PRINT "Staging due to " + sequenceData[0]:NAME + " below the threshold of " + sequenceData[1] + ".".
      STAGE.
      sequenceData:REMOVE(0).
      sequenceData:REMOVE(0).
      IF sequenceData:LENGTH > 0 {
        SET sequenceData[0] TO get_resource(sequenceData[0]).
      }
      RETURN TRUE.
    }
  }
}

FUNCTION get_resource {
  PARAMETER resName.
  FOR res IN SHIP:RESOURCES {
    IF res:NAME = resName {
      RETURN res.
    }
  }
  RETURN LEX("name",resName,"amount",-1,"amount",-1,"density",-1,"parts",LIST()).
}