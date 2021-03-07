FUNCTION staging_check {
  PARAMETER tankTag IS "stagingTank", threshold IS 0.01.
  IF STAGE:READY {
    IF tankTag:ISTYPE("List") {
      FOR tTag IN tankTag {
        IF staging_check(tTag,threshold) {
          RETURN TRUE.
        }
      }
    } ELSE {
      LOCAL tankList IS SHIP:PARTSTAGGED(tankTag).
      IF (tankList:LENGTH > 0) {
        LOCAL shouldStage IS FALSE.
        FOR tank IN tankList {
          FOR res IN tank:RESOURCES {
            IF res:AMOUNT < threshold {
              SET shouldStage TO TRUE.
              BREAK.
            }
          }
          IF shouldStage {
            BREAK.
          }
        }
        IF shouldStage {
          PRINT "Staging due to a resource below threshold".
          STAGE.
        }
        RETURN shouldStage.
      }
    }
  }
  RETURN FALSE.
}