LOCAL timePast IS TIME:SECONDS.
LOCAL impactTime IS timePast.
UNTIL FALSE {
  LOCAL impact IS impact_eta(impactTime).
  LOCAL timeNow IS TIME:SECONDS.
  IF impact > timeNow { SET impactTime TO impact. }
  WAIT 0.
  CLEARSCREEN.
  PRINT "impact ETA: " + ROUND(impact - timeNow,1).
  PRINT "delta Time: " + ROUND(ABS(timePast - timeNow),2).
  SET timePast TO timeNow.
}

FUNCTION impact_eta { //returns the impact time in UT from after the next node, note only works on airless bodies
  PARAMETER posTime IS TIME:SECONDS. //posTime must be in UT seconds (TIME:SECONDS)
  LOCAL stepVal IS 100.
  LOCAL maxScanTime IS SHIP:ORBIT:PERIOD + posTime.
  IF (SHIP:ORBIT:PERIAPSIS < 0) AND (SHIP:ORBIT:TRANSITION <> "escape") {
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
        SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(scanTime,pos):TERRAINHEIGHT.
        IF altitudeAt < targetAltitudeLow {
          SET scanTime TO scanTime - stepVal.
          SET pos TO POSITIONAT(SHIP,scanTime).
          SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(scanTime,pos):TERRAINHEIGHT.
          SET stepVal TO stepVal / 2.
        }
      } ELSE IF altitudeAt < targetAltitudeLow {
        SET scanTime TO scanTime - stepVal.
        SET pos TO POSITIONAT(SHIP,scanTime).
        SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(scanTime,pos):TERRAINHEIGHT.
        IF altitudeAt > targetAltitudeHi {
          SET scanTime TO scanTime + stepVal.
          SET pos TO POSITIONAT(SHIP,scanTime).
          SET altitudeAt TO localBody:ALTITUDEOF(pos) - ground_track(scanTime,pos):TERRAINHEIGHT.
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

FUNCTION ground_track {  //returns the geocoordinates of the ship at a given time(UTs) adjusting for planetary rotation over time
  PARAMETER posTime,pos.
  LOCAL localBody IS SHIP:BODY.
  LOCAL rotationalDir IS VDOT(localBody:NORTH:FOREVECTOR,localBody:ANGULARVEL). //the number of radians the body will rotate in one second
  LOCAL posLATLNG IS localBody:GEOPOSITIONOF(pos).
  LOCAL timeDif IS posTime - TIME:SECONDS.
  LOCAL longitudeShift IS rotationalDir * timeDif * CONSTANT:RADTODEG.
  LOCAL newLNG IS MOD(posLATLNG:LNG + longitudeShift ,360).
  IF newLNG < - 180 { SET newLNG TO newLNG + 360. }
  IF newLNG > 180 { SET newLNG TO newLNG - 360. }
  RETURN LATLNG(posLATLNG:LAT,newLNG).
}//function used but included for easy of reference for impact_eta function