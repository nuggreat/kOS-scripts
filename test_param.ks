The RUN ONCE command can sometimes interfere with parameters being passed into a script.
In the case of the test_print_1 script it can read the parameters the first time it is run but not the second time.
In the course of testing this I discovered it is because of order of execution namely if the RUN ONCE is before the line with PARAMETER then the RUN ONCE will block parameters but only when the script being run with the RUN ONCE has already run.


IF NOT EXISTS("1:/run_me_once_1.ks") { LOG "PRINT 12345." TO "1:/run_me_once_1.ks". }
IF NOT EXISTS("1:/test_print_1.ks") {
  LOG "
    RUN ONCE run_me_once_1.ks.
    PARAMETER printMe IS FALSE.
    PRINT printMe.
  " TO "1:/test_print_1.ks". //will not take in parameter when run any time after the first
}

IF NOT EXISTS("1:/run_me_once_2.ks") { LOG "PRINT 54321." TO "1:/run_me_once_2.ks". }
IF NOT EXISTS("1:/test_print_2") {
  LOG "
    PARAMETER printMe IS FALSE.
    RUN ONCE run_me_once_2.ks.
    PRINT printMe.
  " TO "1:/test_print_param.ks". //will take in parameter when ever it is run
}

PRINT "Should print '12345' then 'test: 1'.".
RUN test_print_param("test: 1").
PRINT "Should print 'test: 2', will print 'FALSE'".
RUN test_print_param("test: 2").
PRINT " ".
PRINT "Should print '54321' then 'test: 3'.".
RUN test_print_2("test: 3").
PRINT "Should print 'test: 4'".
RUN test_print_2("test: 4").