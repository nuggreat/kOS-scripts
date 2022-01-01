//The function staging_check checks for any tanks that match the passed in list and have any resource whos amount is below the threshold
// It takes two parameters
//  One a string for the tag of the tank(s), or a list of tags for the tank(s)
//  Two the AMOUNT that any resouce must be below to trigger staging

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