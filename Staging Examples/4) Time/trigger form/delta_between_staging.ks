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
    "clear",{ SET clearStageing TO TRUE. },
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