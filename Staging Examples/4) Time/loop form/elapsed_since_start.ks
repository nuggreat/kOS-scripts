FUNCTION staging_start {
  PARAMETER stageTimes, absoluteTimes IS FALSE.
  LOCAL sequence IS LIST().
  LOCAL i IS 0.
  FOR stageTime IN stageTimes {
    sequence:ADD(stageTime + i).
    IF NOT absoluteTimes {
      SET i TO i + stageTime.
    }
  }
  RETURN LEX("sequenceStart",TIME:SECONDS,"stageSequence",sequence).
}

FUNCTION staging_check {
  PARAMETER stageData.
  IF STAGE:READY {
    IF stageData:stageSequence:LENGTH > 0 {
      IF ((TIME:SECONDS - stageData:sequenceStart) >= stageData:stageSequence[0]) {
        PRINT "staging".
        STAGE.
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