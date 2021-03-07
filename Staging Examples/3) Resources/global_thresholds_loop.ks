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
  SET sequenceData[0] TO getResource(sequenceData[0]).
  RETURN sequenceData.
}

FUNCTION staging_check {
  PARAMETER sequenceData.
  IF STAGE:READY AND (sequenceData:LENGTH > 0) {
    IF sequenceData[0]:AMOUNT <= sequenceData[1] {
      PRINT "Staging due to " + sequenceData[0]:NAME + " below the threshold of " + sequenceData[1] + ".".
      STAGE.
      sequenceData:REMOVE(0).
      sequenceData:REMOVE(0).
      IF sequenceData:LENGTH > 0 {
        SET sequenceData[0] TO getResource(sequenceData[0]).
      }
      RETURN TRUE.
    }
  }
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