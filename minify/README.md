## lib_minify.ks contains 1 function

### The minify function

  Reduces the sizes of .ks files by removing comments and unneeded white space such as indentation, spaces around parentheses, curly braces, and other symbols, and removing spaces longer than one char.  It does not alter line numbers to aid debug.
  
  This function has 2 parameters
  
    Parameter 1: The path to the file to be reduced, expects something of type string or path
    Parameter 2: The path where the reduced file should be placed, expects something of type string or path
	
  This function has no return.
  
  To illustrate this code snippet from lib_minify.ks
  
    		IF i < contentLength AND whiteSpaceChars:CONTAINS(currentChar) AND whiteSpaceChars:CONTAINS(fileContent[i + 1]) {
    			SET removeLeadingWhite TO TRUE.

    		//comment removal
    		} ELSE IF currentChar = "/" AND i < contentLength AND fileContent[i + 1] {
    			LOCAL j TO i + 2.
    			UNTIL j > contentLength OR fileContent[j] = lf {
    				SET j TO j + 1.
    			}
    			SET fileContent TO fileContent:REMOVE(i,j - i).
    			SET i TO i - 1.
    			SET contentLength TO fileContent:LENGTH - 1.
    
    		//removal of padding around listed chars
    		} ELSE IF removePaddingAround:CONTAINS(currentChar) {

  gets reduced to this
  
    IF i<contentLength AND whiteSpaceChars:CONTAINS(currentChar) AND whiteSpaceChars:CONTAINS(fileContent[i+1]){
    SET removeLeadingWhite TO TRUE.

    
    }ELSE IF currentChar="/"AND i<contentLength AND fileContent[i+1]{
    LOCAL j TO i+2.
    UNTIL j>contentLength OR fileContent[j]=lf{
    SET j TO j+1.
    }
    SET fileContent TO fileContent:REMOVE(i,j-i).
    SET i TO i-1.
    SET contentLength TO fileContent:LENGTH-1.
    
    
    } ELSE IF removePaddingAround:CONTAINS(currentChar){