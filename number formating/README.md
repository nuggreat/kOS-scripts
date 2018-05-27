## lib_formating.ks consists of 5 functions 3 global for use in other scripts and 2 for internal use by the library

### the padding function

  Converts a number into a formated string with a fixed number of digits to the right of the decimal point and a minimum number of digits to the left of the decimal point.
  
  This function has 4 parameters
  
    Parameter 1: expects a number,   number that is to be formated and can be any value.
    Parameter 2: expects a number,   minimum number of digits to the left of the decimal point.
    Parameter 3: expects a number,   number of digits to the right of the decimal point.
	Parameter 4: expects True/False, if true and if Parameter 1 is positive then there will be a space at the start of the returned string, default is true.
  
  Examples of use:
  
    basic use
    padding(1,2,2).   will return the string " 01.00"
    padding(-1,2,2).  will return the string "-01.00"
	
	results of parameter 2
    padding(1,1,2).   will return the string " 1.00"
    padding(-1,1,2).  will return the string "-1.00"
    padding(10,1,2).  will return the string " 10.00" NOTE: because the input number is larger than the minimum defined by the returned string is also longer
	
	results of parameter 3
    padding(1,2,1).   will return the string " 01.0"
    padding(1.1,2,2). will return the string " 01.10"
    padding(1.1,2,0). will return the string " 01"    NOTE: if there are more decimal points than specified by parameter 3 then function will round the number
	
	results of parameter 4
    padding(1,2,2,TRUE).   will return the string " 01.00"
    padding(1,2,2,FALSE).  will return the string "01.00"
    padding(-1,2,2,TRUE).  will return the string "-01.00"
    padding(-1,2,2,FALSE). will return the string "-01.00"
	
### the si_formating function

  Converts a number into a string matching standard SI formats with unit prefixes, will always return with 4 significant digits
  
  this function takes 2 parameters
  
    Parameter 1: expects a number, number that is to be formated expected to be with in the range of 10^-24 to 10^24
	Parameter 2: expects a string, the string representing the unit for of the number, (m, m/s, g, N)
	
  Examples of use:
  
    si_formating(70000,"m").  will return the string " 70.00 km"
    si_formating(0.1,"m").    will return the string " 100.0 mm"
    si_formating(1000.1,"m"). will return the string " 1.000 km"
    si_formating(500,"m/s").  will return the string " 500.0  m/s"
	
### the time_formating function

  Converts number of seconds into a 1 of 7 formated strings for time
  
  this function will detect if you are using the 6 hour KSP day or the 24 hour earth day
  
  for easy of calculation this function is using one year is 426 or 365 (Kerbin year or earth year). If you wish to change this look at changing the local function time_converter NOTE you will need to keep the return the same format or else you will brake other functions
  
  this function takes 4 parameters
  
    Parameter 1: expects a number,   the number of seconds to be formated
	Parameter 2: expects a number,   the type of formating to use, defaults to 0, range from 0 to 6
	Parameter 3: expects a number,   the rounding on the seconds,  defaults to 0, range from 0 to 2
	Parameter 4: expects True/False, if true there will be a T+ or T- depending on if parameter 1 is positive or negative, defaults to False
	
  Examples of use:
  
    time_formating(120).           will return the string " 02m 00s"
    time_formating(120,0,2).       will return the string " 02m 00.00s"
    time_formating(-120,0,2).      will return the string "-02m 00.00s"
    time_formating(-120,0,2,true). will return the string "T- 02m 00.00s"
    time_formating(120,0,2,true).  will return the string "T+ 02m 00.00s"
	
  the 7 format types have different results
  
  formats 0,1,2 will not show higher units than are what is needed for the given input
  
    time_formating(1,0).   will return the string " 01s"
    time_formating(100,0). will return the string " 1m 40s"
	
	
    time_formating(31536000,0). will return the string " 001y 000d 00h 00m 00s"
    time_formating(31536000,1). will return the string " 001 Years, 000 Days, 00:00:00"
    time_formating(31536000,2). will return the string " 001 Years, 000 Days, 00 Hours, 00 Minutes, 00 Seconds"
	
  format 3,4 will only display hours, minutes, and seconds,
  
  format 3 will truncate the length in the same way as formats 0,1,2,
  
  format 4 will always display the hour, minute, second places
  
    time_formating(3600,3). will return the string " 01:00:00"
    time_formating(60,3).   will return the string " 01:00"
	
    time_formating(3600,4). will return the string " 01:00:00"
    time_formating(60,4).   will return the string " 00:01:00"
	
  format 5,6 will display only the 2 highest units for the passed in time they also try to keep the return string the exact same length regardless of input.  Parameter 3 is set to 0 for theses formats and can't be change with out editing the code
  
    time_formating(31536000,5). will return the string " 001y 000d "
    time_formating(86400,5).    will return the string " 001d 00h  "
    time_formating(3600,5).     will return the string " 01h  00m  "
	
    time_formating(31536000,6). will return the string " 001 Years   000 Days    "
    time_formating(86400,6).    will return the string " 001 Days    00 Hours    "
    time_formating(3600,6).     will return the string " 01 Hours    00 Minutes  "
	
	
	
