    - gets passed a list items alternating between strings and scalars starting with the strings
    - the string is the resource name the scalar is the threshold
    - list must start with the first threshold

FUNCTION staging_start {
  PARAMETER sequenceList.
  LOCAL sequenceData IS LIST().
  FROM { LOCAL i IS 0. } UNTIL (i >= sequenceList:LENGTH) STEP { SET i TO i + 2. } DO {
    sequenceData:ADD(sequenceList[0 + i]).
    sequenceData:ADD(MAX(sequenceList[1 + i],0)).
  }
  LOCAL clearStageing IS FALSE.
  SET sequenceData[0] TO getResource(sequenceData[0]).
  WHEN clearStageing OR sequenceData[0]:AMOUNT <= sequenceData[1] THEN {
    IF NOT clearStageing {
      IF STAGE:READY {
        PRINT "Staging due to " + sequenceData[0]:NAME + " below the threshold of " + sequenceData[1] + ".".
        STAGE.
        sequenceData:REMOVE(0).
        sequenceData:REMOVE(0).
        IF sequenceData:LENGTH > 0 {
          SET sequenceData[0] TO getResource(sequenceData[0]).
          PRESERVE.
        }
      } ELSE {
        PRESERVE.
      }
    }
  }
  RETURN LEX("clear",{ SET clearStageing TO TRUE. }).
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