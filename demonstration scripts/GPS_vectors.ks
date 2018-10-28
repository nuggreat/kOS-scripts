PRINT "abort to end script".
PRINT "v to toggle visibility".

LOCAL gpsSatList IS generate_sat_list("GPS").
LOCAL vecDraws IS generate_vec_draws(gpsSatList).
LOCAL gpsSatNumber IS gpsSatList:LENGTH.
LOCAL showVec IS TRUE.
LOCAL vSize IS 0.5.
LOCAL vPressed IS FALSE.

ABORT OFF.
UNTIL ABORT {
  FROM { LOCAL i IS 0. } UNTIL i >= gpsSatNumber STEP { SET i TO i + 1. } DO {
    LOCAL craft IS gpsSatList[i].
    IF showVec AND is_above_horizon(craft) { 
      LOCAL shipCraftVec IS craft:POSITION - SHIP:POSITION.
      SET vecDraws[i]:START TO shipCraftVec.
      SET vecDraws[i]:VEC TO -shipCraftVec.
      SET vecDraws[i]:SHOW TO TRUE.
      SET vecDraws[i]:WIDTH TO vSize.
    } ELSE {
      SET vecDraws[i]:SHOW TO FALSE.
    }
  }
  IF was_v_or_m_pressed() {
    IF vPressed {
      SET vPressed TO FALSE.
      SET showVec TO NOT showVec.
    }
  }
  IF MAPVIEW {
    SET vSize TO 0.5.
  } ELSE {
    SET vSize TO 200.
  }
  WAIT 0.
}
ABORT OFF.
CLEARVECDRAWS().

FUNCTION is_above_horizon {
  PARAMETER sat.
  RETURN VANG(SHIP:UP:FOREVECTOR, sat:POSITION - SHIP:POSITION) < 90.
}

FUNCTION generate_sat_list {
  PARAMETER commonStr.
  LOCAL returnList IS LIST().
  LOCAL craftList IS LIST().
  LIST TARGETS IN craftList.
  FOR craft IN craftList {
    IF craft:NAME:CONTAINS(commonStr) {
      returnList:ADD(craft).
    }
  }
  RETURN returnList.
}

FUNCTION generate_vec_draws {
  PARAMETER craftList.
  LOCAL returnList IS LIST().
  FOR craft IN craftList {
    LOCAL shipCraftVec IS craft:POSITION - SHIP:POSITION.
    returnList:ADD(VECDRAW(shipCraftVec,-shipCraftVec,GREEN,"",1,FALSE,0.5)).
  }
  RETURN returnList.
}

FUNCTION was_v_or_m_pressed {
  LOCAL termIn IS TERMINAL:INPUT.
  IF termIn:HASCHAR {
    LOCAL char IS termIn:GETCHAR().
    IF char = "v" {
      SET vPressed TO TRUE.
      RETURN TRUE.
    }
  }
  RETURN FALSE.
}