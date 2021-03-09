FUNCTION staging_start {
  LOCAL clearStageing IS FALSE.
  WHEN clearStageing OR ((SHIP:AVAILABLETHRUST = 0) AND STAGE:READY) THEN {
    IF NOT clearStageing {
      PRINT "Staging due to no thrust".
      STAGE.
      PRESERVE.
    }
  }
  RETURN LEX("clearTrigger",{ SET clearStageing TO TRUE. PRINT "removed no thrust trigger". }).
}