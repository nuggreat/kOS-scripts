//The staging_start function generates the trigger used for staging and returns a lexicon containing function delegates for control and information
// The trigger will stage based on when enough time has passed since the the function was called the timing is set by the first parameter
// The function takes 2 parameters the first is mandatory the second is optional
//  The first parameter is a list of scalars representing seconds exactly what they should be is set by the second parameter
//   The list is also expected to use normal indexing where the index 0 is the first time in the list
//   If the second parameter is true the list is expected to be sorted with the lowest number at index 0
//  The second parameter is a boolean defaulted to false
//   If false the passed in list of times is expected to be the time between staging events
//   If true  the passed in list of times is expected to be the number of seconds after calling staging_start staging events are expected to happen
//    In this case staging_start will convert the passed in times to match with the first option
// The function returned lexicon will has three delegates one will remove the trigger and the other two provide data as to the current state of the trigger.
//  The key "clear" when called will dispose of the trigger
//  The key "stagesLeft" when called will return the number of staging events left in the programmed sequence
//   Should the "clear" key be called this will return zero
//  The key "timeToNextStage" will return the time difference between the current time and when the next staging event will be
//   The returned value will be positive when the next staging event is in the further and negative if staging time was missed

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
    "clear",{ SET clearStageing TO TRUE. sequence:CLEAR() },
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