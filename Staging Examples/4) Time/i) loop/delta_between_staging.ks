FUNCTION staging_start {
  PARAMETER stageTimes,absoluteTimes IS FALSE.
  LOCAL sequence IS LIST().
  LOCAL i IS 0.
  FOR stageTime IN stageTimes {
    sequence:ADD(TIMESPAN(stageTime - i)).
    IF absoluteTimes {
      SET i TO stageTime.
    }
  }
  RETURN LEX("lastTime",TIME,"stageSequence",sequence).
}

FUNCTION staging_check {
  PARAMETER stageData.
  IF STAGE:READY {
    IF stageData:sequence:LENGTH > 0 {
      IF ((TIME - stageData:lastTime) >= stageData:stageSequence[0]) {
        STAGE.
        SET stageData:lastTime TO TIME.
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
    RETURN stageData:stageSequence[0] - (TIME - stageData:lastTime).
  } ELSE {
    RETURN 0.
  }
}