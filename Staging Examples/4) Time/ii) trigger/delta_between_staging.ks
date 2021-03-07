FUNCTION staging_start {
  PARAMETER stageTimes,absoluteTimes IS TRUE.
  LOCAL sequence IS LIST(0).
  LOCAL i IS 0.
  FOR stageTime IN stageTimes {
    sequence:ADD(TIMESPAN(stageTime - i)).
    IF absoluteTimes {
      SET i TO stageTime.
    }
  }

  LOCAL lastTime IS TIME.
  LOCAL clearStageing IS FALSE.
  WHEN ((TIME - lastTime) >= sequence[0] OR clearStageing) THEN {
    IF (STAGE:READY AND (NOT clearStageing)) {
      STAGE.
      SET lastTime TO TIME.
      sequence:REMOVE(0).
    }
    RETURN NOT(sequence:LENGTH = 0 OR clearStageing).
  }

  RETURN LEX(
    "clear",{ SET clearStageing TO TRUE. },
    "stagesLeft",{ RETURN sequence:LENGTH. },
    "timeToNextStage", {
      IF sequence:LENGTH > 0 {
        RETURN sequence[0] - (TIME - lastTime).
      } ELSE {
        RETURN 0.
      }
    }
  ).
}