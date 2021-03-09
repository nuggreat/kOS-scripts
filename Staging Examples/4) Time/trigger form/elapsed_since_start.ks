FUNCTION staging_start {
  PARAMETER stageTimes,absoluteTimes IS TRUE.
  LOCAL sequence IS LIST().
  LOCAL i IS 0.
  FOR stageTime IN stageTimes {
    sequence:ADD(stageTime + i).
    IF NOT absoluteTimes {
      SET i TO i + stageTime.
    }
  }

  LOCAL startTime IS TIME:SECONDS.
  LOCAL clearStageing IS FALSE.
  LOCAL nextStageTime IS sequence[0].
  WHEN ((TIME:SECONDS - startTime) >= nextStageTime OR clearStageing) THEN {
    IF (STAGE:READY AND (NOT clearStageing)) {
      PRINT "staging".
      STAGE.
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
        RETURN nextStageTime - (TIME:SECONDS - startTime).
      } ELSE {
        RETURN 0.
      }
    }
  ).
}