LOCAL timePast IS TIME:SECONDS.
LOCAL impactTime IS timePast.
UNTIL FALSE {
  LOCAL impact IS impact_eta(impactTime).
  LOCAL timeNow IS TIME:SECONDS.
  IF impact > timeNow { SET impactTime TO impact. }
  CLEARSCREEN.
  PRINT "impact ETA: " + ROUND(impact - timeNow,1).
  PRINT "delta Time: " + ROUND(ABS(timePast - timeNow),2).
  SET timePast TO timeNow.
  WAIT 0.
}

FUNCTION impact_eta { //returns the impact time in UT form after the next node, note only works on airless bodies
  PARAMETER posTime. //posTime must be in UT seconds (TIME:SECONDS)
  LOCAL stepVal IS 100.
  LOCAL maxScanTime IS NEXTNODE:ORBIT:PERIOD + posTime.
  IF (NEXTNODE:ORBIT:PERIAPSIS < 0) AND (NEXTNODE:ORBIT:TRANSITION <> "escape") {
    LOCAL localBody IS SHIP:BODY.
    LOCAL resetTime IS TIME:SECONDS.
    LOCAL resetCounter IS 0.
    LOCAL scanTime IS posTime.
    LOCAL targetAltitudeHi IS 1.
    LOCAL targetAltitudeLow IS 0.
    LOCAL pos IS POSITIONAT(SHIP,scanTime).
    LOCAL altitudeAt IS localBody:ALTITUDEOF(POSITIONAT(SHIP,scanTime)).
    UNTIL (altitudeAt < targetAltitudeHi) AND (altitudeAt > targetAltitudeLow) {
      IF altitudeAt > targetAltitudeHi {
        SET scanTime TO scanTime + stepVal.
        SET pos TO POSITIONAT(SHIP,scanTime).
        SET altitudeAt TO localBody:ALTITUDEOF(pos) - localBody:GEOPOSITIONOF(pos):TERRAINHEIGHT.
        IF altitudeAt < targetAltitudeLow {
          SET scanTime TO scanTime - stepVal.
          SET pos TO POSITIONAT(SHIP,scanTime).
          SET altitudeAt TO localBody:ALTITUDEOF(pos) - localBody:GEOPOSITIONOF(pos):TERRAINHEIGHT.
          SET stepVal TO stepVal / 2.
        }
      } ELSE IF altitudeAt < targetAltitudeLow {
        SET scanTime TO scanTime - stepVal.
        SET pos TO POSITIONAT(SHIP,scanTime).
        SET altitudeAt TO localBody:ALTITUDEOF(pos) - localBody:GEOPOSITIONOF(pos):TERRAINHEIGHT.
        IF altitudeAt > targetAltitudeHi {
          SET scanTime TO scanTime + stepVal.
          SET pos TO POSITIONAT(SHIP,scanTime).
          SET altitudeAt TO localBody:ALTITUDEOF(pos) - localBody:GEOPOSITIONOF(pos):TERRAINHEIGHT.
          SET stepVal TO stepVal / 2.
        }
      }
      IF (resetTime + 10) < TIME:SECONDS {//resets loop if it takes more than 10 seconds
        SET scanTime TO posTime.
        SET stepVal TO 100.
        SET resetTime TO TIME:SECONDS.
        SET resetCounter TO resetCounter + 1.
        IF resetCounter >= 3 { SET scanTime TO -1. BREAK. }
      }
      IF maxScanTime < scanTime {//resets loop if it is bigger than one period
        SET scanTime TO posTime.
        SET stepVal TO stepVal / 2.
        SET resetTime TO TIME:SECONDS.
        SET resetCounter TO resetCounter + 1.
        IF resetCounter >= 3 { SET scanTime TO -1. BREAK. }
      }
    }
    RETURN scanTime.
  } ELSE {
    RETURN -1.
  }
}