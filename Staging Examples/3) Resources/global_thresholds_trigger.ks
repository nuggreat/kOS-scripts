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

FUNCTION get_resource {
  PARAMETER resName.
  FOR res IN SHIP:RESOURCES {
    IF res:NAME = resName {
      RETURN res.
    }
  }
  RETURN LEX("name",resName,"amount",-1,"amount",-1,"density",-1,"parts",LIST()).
}