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
// LOCAL stagingStruct IS staging_start(LIST(
  // 0,
  // 13.4,
  // 29,
  // 48
// ),TRUE).
LOCAL stagingStruct IS staging_start(LIST(
  0,
  13.4,
  15.6,
  19
),FALSE).

PRINT "initial pitch maneuver".
UNTIL VERTICALSPEED > vMax AND VANG(SRFPROGRADE:VECTOR,UP:VECTOR) > initalPitch {
  SET tarPitch TO 90 - MAX(MIN(VERTICALSPEED / vMax,initalPitch) * initalPitch,0).
  LOCAL currentAcc IS MAX(SHIP:AVAILABLETHRUST,0.001) / SHIP:MASS.
  LOCAL desiredSpeed IS speed_given_ap(ALTITUDE + bodyRad, targetAP).
  SET throt TO ((desiredSpeed - SHIP:VELOCITY:ORBIT:MAG) / currentAcc).
  WAIT 0.
}

PRINT "surface prograde follow".
LOCK STEERING TO SRFPROGRADE.
UNTIL ALTITUDE > orbitTransition {
  LOCAL currentAcc IS MAX(SHIP:AVAILABLETHRUST,0.001) / SHIP:MASS.
  LOCAL desiredSpeed IS speed_given_ap(ALTITUDE + bodyRad, targetAP).
  SET throt TO ((desiredSpeed - SHIP:VELOCITY:ORBIT:MAG) / currentAcc).
  WAIT 0.
}

PRINT "circularizing orbit".
LOCK STEERING TO PROGRADE.
UNTIL PERIAPSIS > targetAP - 250 {
  LOCAL currentAcc IS MAX(SHIP:AVAILABLETHRUST,0.001) / SHIP:MASS.
  LOCAL desiredSpeed IS SQRT(bodyMu / (APOAPSIS + bodyRad)).
  SET throt TO ((desiredSpeed - SHIP:VELOCITY:ORBIT:MAG) / currentAcc) - signed_eta_ap() + 1.
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
  PARAMETER stageTimes,absoluteTimes IS TRUE.
  LOCAL sequence IS LIST().
  LOCAL i IS 0.
  FOR stageTime IN stageTimes {
    sequence:ADD(stageTime - i).
    IF absoluteTimes {
      SET i TO stageTime.
    }
  }
  
  LOCAL lastTime IS TIME:SECONDS.
  LOCAL clearStageing IS FALSE.
  LOCAL nextStageTime IS sequence[0].
  WHEN (((TIME:SECONDS - lastTime) >= nextStageTime) OR clearStageing) THEN {
    IF (STAGE:READY AND (NOT clearStageing)) {
      PRINT "staging".
      STAGE.
      SET lastTime TO TIME:SECONDS.
      sequence:REMOVE(0).
      IF sequence:LENGTH <> 0 {
        SET nextStageTime TO sequence[0].
      }
    }
    RETURN NOT(sequence:LENGTH = 0 OR clearStageing).
  }

  RETURN LEX(
    "clear",{ SET clearStageing TO TRUE. sequence:CLEAR() },
    "stagesLeft",{ RETURN sequence:LENGTH. },
    "timeToNextStage", {
      IF sequence:LENGTH > 0 {
        RETURN nextStageTime - (TIME:SECONDS - lastTime).
      } ELSE {
        RETURN 0.
      }
    }
  ).
}