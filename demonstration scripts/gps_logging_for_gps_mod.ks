LOCAL varConstants IS LEX("numList",LIST("0","1","2","3","4","5","6","7","8","9")).
LOCAL gpsPart IS SHIP:PARTSTAGGED("GPS")[0].
LOCAL gpsMod IS gpsPart:GETMODULE("KerbalGPS").
LOCAL gpsLog IS LIST().

LOCAL wasLpressed IS FALSE.
LOCAL wasVpressed IS FALSE.
LOCAL wasEpressed IS FALSE.
LOCAL wasPlusPressed IS FALSE.
LOCAL wasMinusPressed IS FALSE.

LOCAL logPath IS "0:/GPS_log.txt".
IF EXISTS(logPath) { DELETEPATH(logPath). }
LOG "time,latitude,longitude,altitude,accuracy,visible sats" TO logPath.

CLEARSCREEN.
PRINT "press l to start logging" AT(0,0).
UNTIL wasLpressed { was_key_pressed(). }.
PRINT "press l to stop logging " AT(0,0).

SET wasLpressed TO FALSE.
SET markTime TO TIME:SECONDS.
UNTIL wasLpressed {
  LOCAL pos IS gpsMod:GETFIELD("position"):SPLIT(" ").
  LOCAL altVal IS gpsMod:GETFIELD("altitude").
  LOCAL satsVis IS gpsMod:GETFIELD("visible satellites").
  LOCAL accVal IS gpsMod:GETFIELD("accuracy").
  SET altVal TO string_to_number(altVal).
  SET satsVis TO string_to_number(satsVis).
  SET accVal TO string_to_number(accVal).
  
  LOCAL latVal IS string_to_number(pos[0]) + (string_to_number(pos[1]) / 60).
  IF pos[2] = "S" {
    SET latVal TO -latVal.
  }
  PRINT "lat: " + ROUND(latVal,4) + "      " AT(0,1).
  
  LOCAL lngVal IS string_to_number(pos[3]) + (string_to_number(pos[4]) / 60).
  IF pos[5] = "W" {
    SET lngVal TO -lngVal.
  }
  PRINT "lng: " + ROUND(lngVal,4) + "      " AT(0,2).
  
  PRINT "alt: " + ROUND(altVal,4) + "      " AT(0,3).
  PRINT "sat: " + ROUND(satsVis,4) + "      " AT(0,4).
  PRINT "acc: " + ROUND(accVal,4) + "      " AT(0,5).
  gpsLog:ADD(LIST(latVal,lngVal,altVal,accVal)).
  LOG TIME:SECONDS + "," + latVal + "," + lngVal + "," + altVal + "," + accVal + "," + satsVis TO logPath.
  was_key_pressed().
  adv_wait(1).
}

CLEARSCREEN.
PRINT "press V to show/hide vectors".
PRINT "press +/- to change width".
PRINT "press E to end script".

LOCAL smallestError IS 2^10.
LOCAL largestError IS -2^10.
FOR gpsData IN gpsLog {
  LOCAL errorVal IS gpsData[3].
  IF errorVal > largestError {
    SET largestError TO errorVal.
  }
  IF errorVal < smallestError {
    SET smallestError TO errorVal.
  }
}

LOCAL gpsLogLength IS gpsLog:LENGTH.
LOCAL vecList IS LIST().
FROM { LOCAL i IS 1. } UNTIL i >= gpsLogLength STEP { SET i TO i + 1. } DO {
  LOCAL gpsDataNew IS gpsLog[i].
  LOCAL gpsDataOld IS gpsLog[i - 1].
  LOCAL newPos IS LATLNG(gpsDataNew[0],gpsDataNew[1]):ALTITUDEPOSITION(gpsDataNew[2] + 1).
  LOCAL oldPos IS LATLNG(gpsDataOld[0],gpsDataOld[1]):ALTITUDEPOSITION(gpsDataOld[2] + 1).
  LOCAL oldNewVec IS newPos - oldPos.
  LOCAL errorVal IS (gpsDataNew[3] + gpsDataOld[3]) / 2.
  vecList:ADD(VECDRAW(oldPos,oldNewVec,rgb_gen(largestError,smallestError,errorVal),"",1,TRUE,1)).
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

FUNCTION string_to_number {
  PARAMETER str,removeEndDP IS FALSE.
  IF str:ISTYPE("string") {
    LOCAL localString IS str.
    LOCAL didChange IS FALSE.
    LOCAL dpLocation IS 0.
    FROM {LOCAL i IS localString:LENGTH - 1.} UNTIL i < 0 STEP {SET i TO i - 1.} DO {
      IF NOT varConstants["numList"]:CONTAINS(localString[i]) {
        IF localString[i] = "." {
          IF dpLocation <> 0 {
            SET didChange TO TRUE.
            SET localString TO localString:REMOVE(dpLocation,1).
          }
          SET dpLocation TO i.
        } ELSE IF NOT (i = 0 AND localString[i] = "-" ) {
          SET didChange TO TRUE.
          SET localString TO localString:REMOVE(i,1).
        }
      }
    }
    IF removeEndDP AND (dpLocation = (localString:LENGTH - 1)) {
      SET didChange TO TRUE.
      localString:REMOVE(localString:LENGTH - 1,1).
    }
    IF localString:LENGTH = 0 {
      SET didChange TO TRUE.
      SET localString TO "0".
    }
    IF didChange {
      RETURN localString:TONUMBER(0).
    } ELSE {
      RETURN str.
    }
  } ELSE {
    RETURN str.
  }
}

FUNCTION rgb_gen {  //returns a color for vecDraw
  PARAMETER maxVal,minVal,val.
  LOCAL divisor IS maxVal - minVal.
  LOCAL adjustedVal IS val - minVal.
  LOCAL re IS MIN(ROUND((1 - adjustedVal / divisor) * 2),1).
  LOCAL gr IS MIN(ROUND((adjustedVal / divisor) * 2),1).
  RETURN RGB(re,gr,0).
}