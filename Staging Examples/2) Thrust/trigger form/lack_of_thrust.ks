FUNCTION staging_start {
  LOCAL clearStageing IS FALSE.
  WHEN clearStageing OR (SHIP:AVAILABLETHRUST = 0) THEN {
    IF NOT clearStageing {
      PRINT "Staging due to no thrust".
      STAGE.
      PRESERVE.
    }
  }
  RETURN LEX("clear",{ SET clearStageing TO TRUE. }).
}