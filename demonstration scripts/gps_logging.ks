LOCAL varConstants IS LEX("numList",LIST("0","1","2","3","4","5","6","7","8","9")).
LOCAL gpsLog IS LIST().

LOCAL wasLpressed IS FALSE.
LOCAL wasVpressed IS FALSE.
LOCAL wasEpressed IS FALSE.
LOCAL wasPlusPressed IS FALSE.
LOCAL wasMinusPressed IS FALSE.

LOCAL logPath IS "0:/GPS_log.txt".
IF EXISTS(logPath) { DELETEPATH(logPath). }
LOG "time,latitude,longitude,altitude" TO logPath.

CLEARSCREEN.
PRINT "press l to start logging" AT(0,0).
UNTIL wasLpressed { was_key_pressed(). }.
PRINT "press l to stop logging " AT(0,0).

SET wasLpressed TO FALSE.
SET markTime TO TIME:SECONDS.
UNTIL wasLpressed {
  LOCAL geoPos IS SHIP:GEOPOSITION.
  LOCAL altVal IS SHIP:ALTITUDE.
  
  LOCAL latVal IS geoPos:LAT.
  PRINT "lat: " + ROUND(latVal,4) + "      " AT(0,1).
  
  LOCAL lngVal IS geoPos:LNG.
  PRINT "lng: " + ROUND(lngVal,4) + "      " AT(0,2).
  
  PRINT "alt: " + ROUND(altVal,4) + "      " AT(0,3).
  
  gpsLog:ADD(LIST(latVal,lngVal,altVal)).
  LOG TIME:SECONDS + "," + latVal + "," + lngVal + "," + altVal TO logPath.
  was_key_pressed().
  adv_wait(1).
}

CLEARSCREEN.
PRINT "press V to show/hide vectors".
PRINT "press +/- to change width".
PRINT "press E to end script".

LOCAL smallestSpeed IS 2^10.
LOCAL largestSpeed IS -2^10.
LOCAL gpsLogLength IS gpsLog:LENGTH.
FROM { LOCAL i IS 1. } UNTIL i >= gpsLogLength STEP { SET i TO i + 1. } DO {
  LOCAL gpsDataNew IS gpsLog[i].
  LOCAL gpsDataOld IS gpsLog[i - 1].
  LOCAL newPos IS LATLNG(gpsDataNew[0],gpsDataNew[1]):ALTITUDEPOSITION(gpsDataNew[2] + 1).
  LOCAL oldPos IS LATLNG(gpsDataOld[0],gpsDataOld[1]):ALTITUDEPOSITION(gpsDataOld[2] + 1).
  LOCAL segSpeed IS (newPos - oldPos):MAG.
  IF segSpeed > largestSpeed {
    SET largestSpeed TO segSpeed.
  }
  IF segSpeed < smallestSpeed {
    SET smallestSpeed TO segSpeed.
  }
}

LOCAL vecList IS LIST().
FROM { LOCAL i IS 1. } UNTIL i >= gpsLogLength STEP { SET i TO i + 1. } DO {
  LOCAL gpsDataNew IS gpsLog[i].
  LOCAL gpsDataOld IS gpsLog[i - 1].
  LOCAL newPos IS LATLNG(gpsDataNew[0],gpsDataNew[1]):ALTITUDEPOSITION(gpsDataNew[2] + 2).
  LOCAL oldPos IS LATLNG(gpsDataOld[0],gpsDataOld[1]):ALTITUDEPOSITION(gpsDataOld[2] + 2).
  LOCAL oldNewVec IS newPos - oldPos.
  vecList:ADD(VECDRAW(oldPos,oldNewVec,rgb_gen(largestSpeed,smallestSpeed,oldNewVec:MAG),"",1,TRUE,1)).
  WAIT 0.
}

LOCAL widthCoef IS 0.
LOCAL showVec IS TRUE.
SET wasEpressed TO FALSE.
LOCAL TRUE IS FALSE.
UNTIL wasEpressed {
  was_key_pressed().
  IF wasVpressed OR wasPlusPressed OR wasMinusPressed {
    IF wasMinusPressed {
      SET widthCoef TO widthCoef - 1.
      SET wasMinusPressed TO FALSE.
    }
    IF wasPlusPressed {
      SET widthCoef TO widthCoef + 1.
      SET wasPlusPressed TO FALSE.
    }
    IF wasVpressed {
      SET showVec TO NOT showVec.
      SET wasVpressed TO FALSE.
    }
	FROM { LOCAL i IS 0. } UNTIL i >= vecList:LENGTH STEP { SET i TO i + 1. } DO {
      LOCAL vecD IS vecList[i].
      SET vecD:SHOW TO showVec.
      SET vecD:WIDTH TO 2^widthCoef.
	  WAIT 0.
	}
  }
  WAIT 0.
}

CLEARVECDRAWS().

FUNCTION was_key_pressed {
  LOCAL termIn IS TERMINAL:INPUT.
  IF termIn:HASCHAR {
    LOCAL char IS termIn:GETCHAR().
    IF char = "+" {
      SET wasPlusPressed TO TRUE.
    } ELSE IF char = "-" {
      SET wasMinusPressed TO TRUE.
    } ELSE IF char = "v" {
      SET wasVpressed TO TRUE.
    } ELSE IF char = "l" {
      SET wasLpressed TO TRUE.
    }  ELSE IF char = "e" {
      SET wasEpressed TO TRUE.
    }
  }
}

FUNCTION was_v_pressed {
  LOCAL termIn IS TERMINAL:INPUT.
  IF termIn:HASCHAR {
    RETURN termIn:GETCHAR() = "v".
  } ELSE {
    RETURN FALSE.
  }
}

FUNCTION adv_wait {
  PARAMETER pause.
  SET markTime TO markTime + pause.
  WAIT UNTIL TIME:SECONDS >= markTime.
}

FUNCTION rgb_gen {  //returns a color for vecDraw
  PARAMETER maxVal,minVal,val.
  LOCAL divisor IS maxVal - minVal.
  LOCAL adjustedVal IS val - minVal.
  LOCAL re IS MIN((1 - adjustedVal / divisor) * 2,1).
  LOCAL gr IS MIN((adjustedVal / divisor) * 2,1).
  RETURN RGB(re,gr,0).
}