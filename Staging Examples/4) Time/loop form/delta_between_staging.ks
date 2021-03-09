FUNCTION staging_start {
  PARAMETER stageTimes, absoluteTimes IS FALSE.
  LOCAL sequence IS LIST().
  LOCAL i IS 0.
  FOR stageTime IN stageTimes {
    sequence:ADD(stageTime - i).
    IF absoluteTimes {
      SET i TO stageTime.
    }
  }
  RETURN LEX("lastTime",TIME:SECONDS,"stageSequence",sequence).
}

FUNCTION staging_check {
  PARAMETER stageData.
  IF STAGE:READY {
    IF stageData:stageSequence:LENGTH > 0 {
      IF ((TIME:SECONDS - stageData:lastTime) >= stageData:stageSequence[0]) {
        PRINT "staging".
        STAGE.
        SET stageData:lastTime TO TIME:SECONDS.
        stageData:stageSequence:REMOVE(0).
        RETURN TRUE.
      }
    }
  }
  RETURN FALSE.
}

FUNCTION staging_eta {//positave means it is pending, negitave means it is past
  PARAMETER stageData.
  IF stageData:stageSequence:LENGTH > 0 {
    RETURN stageData:stageSequence[0] - (TIME:SECONDS - stageData:lastTime).
  } ELSE {
    RETURN 0.
  }
}