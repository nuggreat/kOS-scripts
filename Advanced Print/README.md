lib_advanced_print is a library containing the functions needed to configure and use the new print function that is superior to the basic print that comes native to kOS

## Functions

### adv_print

  is the function used to convey the information passed into it

**Parameter(s) and return value(s)**

  one required parameter

    1) a text string to be converted into the superior information format that then will be conveyed to the user

  no return value

**Notes about function**

  most settings about this funciton are configured by the adv_print_config function

  this function recognizes the charters "a" through "z" the numbers 0 through 9

  there are also a few special charters that will be expanded into other strings said charters are:

    "<" will become the string "greater than"
    ">" will become the string "less than"
    "=" will become the string "equal"
    "!" will become the string "not"
    "@" will become the string "at"
    "&" will become the string "and"
    "|" will become the string "or"
    "." will become the string "point"
    "#" will become the string "supercalifragilisticexpialidocious"
    "%" will become the string "abcdefghijklmnopqrstuvwxyz0123456789"

### adv_print_config

  used to set of the configure the various options about the adv_print function

**Parameter(s) and return value(s)**

  ten optional parameter

    1) the basic timing unit in seconds needed for the superior information delivery format that advanced print lib uses
      defaulted to 0.1 seconds
    2) a flag for if the adv_print function should display the superior information format on the terminal
      defaulted to false, true will display on the terminal
    3) a flag for if the adv_print function should display the superior information format on the KSP HUD
      defaulted to false, true will display on the KSP HUD
    4) a flag for if the adv_print function should convey the superior information format through sound
      defaulted to true, true will play the sound
    5) the frequency in Hz of the sound used to convey the dot of the superior information format
      defaulted to 440 Hz
    6) the frequency in Hz of the sound used to convey the dash of the superior information format
      defaulted to 440 Hz
    7) the volume of the sound used to convey the superior information format
      defaulted to 1, the loudest setting
    8) the color of the HUD text can be any RGB value
      defaulted to WHITE
    9) the size of the HUD text
      defaulted to 40
    10) the location the HUD text will appear in can be a number between 1 and 4
      defaulted to 2, will place the HUD text just below the altimeter in the center of the screen
    
      more information on HUD text can be found [here](http://ksp-kos.github.io/KOS_DOC/commands/terminalgui.html#global:HUDTEXT)
    
  no return value

**Notes about function**

  this function is used to customize how the superior information format will be conveyed

## Local Functions

### parse

  takes in a string converts it into a different string

**Parameter(s) and return value(s)**

  two required parameters

    1) the string to be converted
    2) a LEXICON with individual charters as keys and a string as the value

  one optional parameter

    1) a list of charters to just pass through

  returns a string

**Notes about function**

  if a charter is not in the keys or the list it be ignored by the function

  example of use:

    LOCAL str IS "abc".
    LOCAL replaceLex IS LEX("a","z").
    LOCAL passThroughList IS LIST("b").
    PRINT parse(str,replaceLex,passThroughList).//will print the string "zb" discarding the c charter

### compose

  takes in a string in a precursor format to the superior format returns a lexicon with a list string and list of notes

**Parameter(s) and return value(s)**

  one required parameters

    1) the string to be converted

  returns a lexicon with "sound" and "text" as the keys
    "sound" contains the list of notes in the superior format
    "text"  contains list of lists with string and timing

**Notes about function**

  the "text" return is a special format to convey the superior format to the terminal with the correct timing
  the "sound" return can be played as any other list of SKID notes, a sine wave is the recommended wave form

### adv_wait

  used to get waits of a given length between calls of the function regardless of how many instructions execute in between calls of the function

**Parameter(s) and return value(s)**

  one required parameters

    1) the amount of time to wait in seconds

  returns nothing

**Notes about function**

  function uses a var local to the entire library called markTime

  example of use:

    SET markTime TO TIME:SECONDS.//how you init the time the function should start counting from
    ...some code...
    adv_wait(1).//will let the script resume exactly one second after the set markTime
    ...some more code...
    adv_wait(1).//will let the script resume exactly two second after the set markTime and thus 1 second after the the first call of adv_wait


### terminal_print

  used to print the superior information format to the terminal keeping track of what charter the print is on as using new lines as needed

**Parameter(s) and return value(s)**

  one required parameters

    1) a string

  returns nothing

**Notes about function**

  will keep the passed in strings contiguous where a normal print will start on a new line with what ever charters overflowed the last line this function will use new lines to keep from braking up the passed in strings

  example of use:

    //function called several times with different strings
    terminal_print("hello ").
    terminal_print("world ").
    terminal_print("this ").
    terminal_print("is ").
    terminal_print("an ")
    terminal_print("example").

    in below the // denote the border of a terminal that is 10 columns wide and 4 rows tall
    //////////////
    //hello     //
    //world     //
    //this is   //
    //an example//
    //////////////
    
### hud_print

**Parameter(s) and return value(s)**

  displays the superior information format using KSP hud text

  two required parameters

    1) a string
    2) the fade time on the displayed text

  returns nothing

**Notes about function**

  has 3 settings configured by adv_print_config for placement, size, and color of the text

### dot

  add fixed things to two passed in lists used by compose function to generate it's return

**Parameter(s) and return value(s)**

  two required parameters

    1) a list that should have notes added to it
    2) a list that should have a list consisting of a string and timing information

  returns nothing

**Notes about function**

  used to add the dot aspect of the superior information format

### dash

  add fixed things to two passed in lists used by compose function to generate it's return

**Parameter(s) and return value(s)**

  two required parameters

    1) a list that should have notes added to it
    2) a list that should have a list consisting of a string and timing information

  returns nothing

**Notes about function**

  used to add the dash aspect of the superior information format

### space_char

  add fixed things to two passed in lists used by compose function to generate it's return

**Parameter(s) and return value(s)**

  two required parameters

    1) a list that should have notes added to it
    2) a list that should have a list consisting of a string and timing information

  returns nothing

**Notes about function**

  used to add the space between charters of the superior information format

### space_letter

  add fixed things to two passed in lists used by compose function to generate it's return

**Parameter(s) and return value(s)**

  two required parameters

    1) a list that should have notes added to it
    2) a list that should have a list consisting of a string and timing information

  returns nothing

**Notes about function**

  used to add the space between letters of the superior information format

### space_word

  add fixed things to two passed in lists used by compose function to generate it's return

**Parameter(s) and return value(s)**

  two required parameters

    1) a list that should have notes added to it
    2) a list that should have a list consisting of a string and timing information

  returns nothing

**Notes about function**

  used to add the the space between the words of the superior information format
  
