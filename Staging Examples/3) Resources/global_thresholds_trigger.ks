//The function staging_start creates a trigger and assoceated lexicon to remove the trigger when it is no longer needed.
// It takes in one parameter: A list of string and number pairs, the first threshold must be the first pair in the list the second will be the second pair and so on
//  The string is a internal resource name
//  The number is how low that resource must drop to trigger that staging
// The retuned lexicon has one key "clearTrigger" which when called will clear the trigger.

FUNCTION staging_start {
  PARAMETER sequenceList.
  LOCAL sequenceData IS LIST().
  FROM { LOCAL i IS 0. } UNTIL (i >= sequenceList:LENGTH) STEP { SET i TO i + 2. } DO {
    sequenceData:ADD(sequenceList[0 + i]).
    sequenceData:ADD(MAX(sequenceList[1 + i],0)).
  }
  LOCAL clearStageing IS FALSE.
  LOCAL currentRes IS get_resource(sequenceData[0]).
  LOCAL currentThreshold IS sequenceData[1].
  WHEN clearStageing OR (currentRes:AMOUNT <= currentThreshold) THEN {
    IF NOT clearStageing {
      IF STAGE:READY {
        PRINT "Staging due to " + currentRes:NAME + " below the threshold of " + currentThreshold + ".".
        STAGE.
        sequenceData:REMOVE(0).
        sequenceData:REMOVE(0).
        IF sequenceData:LENGTH > 0 {
          SET currentRes TO get_resource(sequenceData[0]).
          SET currentThreshold TO sequenceData[1].
          PRESERVE.
        }
      } ELSE {
        PRESERVE.
      }
    }
  }
  RETURN LEX("clearTrigger",{ SET clearStageing TO TRUE. PRINT "removed global resource trigger". }).
}

//The function get_resource returns the resourceAgrogate for the resource of the passed in name
// It takes one parameter: the name of the resource
// If there is no resource that has that name on the ship it will instead return a lexicon that can stand in for a resourceAgrogate

FUNCTION get_resource {
  PARAMETER resName.
  FOR res IN SHIP:RESOURCES {
    IF res:NAME = resName {
      RETURN res.
    }
  }
  RETURN LEX("name",resName,"amount",-1,"amount",-1,"density",-1,"parts",LIST()).
}