CLEARSCREEN.
SAS OFF.
RCS OFF.
BRAKES OFF.
SET TERMINAL:WIDTH TO 45.
SET TERMINAL:HEIGHT TO 15.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 1.
SET markNum TO 0.
SET destnation TO 0.

SET headingAngle TO 90.
SET pitchAngle TO 0.
SET cruseHeight TO 8000.

SET maxAngleUp TO 9.
SET MaxAngleDown TO 15.
SET tS TO 0.1.
SET done TO FALSE.
SET distPrev TO 0.
SET timePrev TO TIME:SECONDS.
SET distAngle TO 0.
SET deltaDist TO 0.
SET deltaDistAvr TO 0.
SET deltaDistlIST TO LIST().
SET timeTo TO 999999.
SET listPlace TO 0.
SET scrUpdate TO 10 - 10 * tS.

IF destnation = 0
{
  SET points TO ALLWAYPOINTS().
  SET mark TO points[markNum]:GEOPOSITION.
//  SET TARGET TO points[markNum].
}
ELSE
{
  SET markNum TO 0.
  SET points TO LIST("Kerbal Space Center").
  SET mark to LATLNG(0,-75).
}
SET distAngle TO ABS(ARCCOS(((mark:TERRAINHEIGHT + 600000) ^ 2 + (ALTITUDE + 600000) ^ 2 - (mark:DISTANCE) ^ 2) / (2 * (mark:TERRAINHEIGHT + 600000) * (ALTITUDE + 600000)))).
SET distPrev TO (distAngle / 360 * (CONSTANT():PI * 600000 * 2)).

UNTIL listPlace > (10 / tS - 1)
{
  deltaDistlIST:ADD(0).
  SET listPlace to listPlace + 1.
}
SET listPlace TO 0.

LOCK STEERING TO HEADING(headingAngle,pitchAngle).

PRINT "Accelerating".
WAIT UNTIL GROUNDSPEED>50.
SET pitchAngle TO 5.
PRINT "climbing to: "+cruseHeight.
WAIT UNTIL ALTITUDE > 100.
GEAR OFF.

UNTIL done
{

  IF mark:BEARING > 0.01 * tS
  {
    SET headingAngle TO headingAngle + ((LOG10(ABS(mark:BEARING) + 1) / 2.25) * tS).
  }
  IF mark:BEARING < 0.01 * tS
  {
    SET headingAngle TO headingAngle - ((LOG10(ABS(mark:BEARING) + 1) / 2.25) * tS).
  }

  IF headingAngle < 0
  {
    SET headingAngle TO 360 + headingAngle.
  }
  IF headingAngle > 360
  {
    SET headingAngle TO headingAngle - 360.
  }

  IF ALTITUDE > (cruseHeight + 25 - (VERTICALSPEED * 50)) AND (VERTICALSPEED > ((cruseHeight - ALTITUDE) / 100))
  {
    SET pitchAngle TO MAX((pitchAngle - (MAX((ABS(VERTICALSPEED / 50) + ABS((ALTITUDE - cruseHeight) / 10000)),0.001) * tS)), 0 - maxAngleDown).
  }
  IF ALTITUDE < (cruseHeight - 25 - (VERTICALSPEED * 50)) AND (VERTICALSPEED < ((cruseHeight - ALTITUDE) / 100))
  {
    SET pitchAngle TO MIN((pitchAngle + (MAX((ABS(VERTICALSPEED / 50) + ABS((ALTITUDE - cruseHeight) / 10000)),0.001) * tS)), maxAngleUp).
  }

  IF scrUpdate > (1 / tS)
  {

    deltaDistList:REMOVE(listPlace).
    SET distAngle TO ABS(ARCCOS(((mark:TERRAINHEIGHT + 600000) ^ 2 + (ALTITUDE + 600000) ^ 2 - (mark:DISTANCE) ^ 2) / (2 * (mark:TERRAINHEIGHT + 600000) * (ALTITUDE + 600000)))).
    deltaDistList:INSERT(listPlace,distPrev - (distAngle / 360 * (CONSTANT():PI * 600000 * 2))).
    SET distPrev TO distAngle / 360 * (CONSTANT():PI * 600000 * 2).
    SET listPlace TO ListPlace + 1.
    IF listPlace > (10 / tS - 1) {SET listPlace TO 0.}

    SET deltaDistAvr TO 0.
    FOR deltaDist IN deltaDistList
      {SET deltaDistAvr TO deltaDistAvr + deltaDist.}
    SET timeTo TO distPrev / (deltaDistAvr / deltaDistList:LENGTH) / (60 / (TIME:SECONDS - timePrev)).

    CLEARSCREEN.
    PRINT "Dentnation: " + points[markNum].
    PRINT " ".
    PRINT "Distance:   " + ROUND(distPrev).
    PRINT "ETA(Min):   " + ROUND(timeto).
    PRINT " ".
    PRINT "Heading:    " + ROUND(headingAngle,3).
    PRINT "Pitch:      " + ROUND(pitchAngle,3).
    PRINT "Bearing:    " + ROUND(mark:BEARING,3).
    SET timePrev TO TIME:SECONDS.
    SET scrUpdate TO 0.
  }
  SET scrUpdate TO scrUpdate + 1.
  WAIT tS.

  SET done TO distPrev < 30000 OR RCS.
}
ADDALARM("RAW",TIME:SECONDS+1,"Auto Pilot Shudown","Notes").
UNLOCK STEERING.
SAS ON.