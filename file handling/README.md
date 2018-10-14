scripts for file handling in kOS and the lib needed to run them


**The script file_util.ks has 12 functions controlled through a in game GIU**

  The script requires the lib lib_file_util.ks and will need to have the RUNPATHONCE edited to point at the copy of the lib on the local volume or use the version called file_util_standalone.ks as that doesn't need the lib.

  the 12 functions are sorted into 2 categories 1st is called "File Tools" the 2nd is "Directory Tools" these categories are in the form of 2 buttons at the top of the GUI.  A dropdown menu below the tool buttons is where you select the exact function you want to use.
  
  the button labeled "Done" will end the script
  
  NOTE: as the file_util script is so large it is recommended you make a compiled version to speed up load times on boot as it can take several seconds to start after having typed RUN
  
  File Tools:
  
    Copy Files: Copies a file defined by Source to the directory defined by Destination
    Compile Files: Compiles a file defined by Source to the directory defined by Destination
    Move Files: Moves a file defined by Source to the directory defined by Destination
    Delete Files: Deletes a file defined by Source
    Rename Files: Renames a file defined by Source
      Has a text field for user input to set the new file name
    Edit Files: Calls kOS edit command for a file defined by Source
    
  Directory Tools:
  
    Copy Directory: Copies a directory by Source to the directory defined by Destination 
    Move Directory: Moves a directory by Source to the directory defined by Destination 
    New Directory: Makes a new Directory defined by the Source
      Has a text field for user input to set the new Directory name
    Unpack Directory: Copies the entire contents of a directory defined by Source to the directory defined by Destination
    Update Local Volume: A inbuilt version of updater.ks has buttons for all 4 flags
    Delete Directory: Deletes a directory defined by Source
    
  Source:
  
    Source is a set of 2 or 3 drop down lists that define a directory or file
      1st dropdown: a selection for volume with 2 options (defaults to Archive)
        Archive: is the folder in the KSP directory that kOS intends you to have your scripts saved so they can be read in game
        Local: is the volume used by the kOS core that ran the script used for local storage of scripts
      2nd dropdown: a dropdown list of all directories in the volume selected by Source dropdown 1
      3rd dropdown: a dropdown list of all files found in the directory selected by Source dropdown 2
        3rd dropdown is invisible for all Directory Tools as they don't interact with files directly
        will display size of selected file
        
  Destination:
  
    Destination is a set of 2 drop down lists that define second directory
      1st dropdown: a selection for volume with 2 options (defaults to local)
        Archive: is the folder in the KSP directory that kOS intends you to have your scripts saved so they can be read in game
        Local: is the volume used by the kOS core that ran the script used for local storage of scripts
      2nd dropdown: a dropdown list of all directories in the volume selected by Destination dropdown 1
        will display space remaining in selected volume

 
**The script Updater.ks will scan the local kOS volumes for files and then update the local files with the copies from the archive volume.**

  The script requires the lib lib_file_util.ks and will need to have the RUNPATHONCE edited to point at the copy of the lib on the local volume or use the version called Updater_standalone.ks as that doesn't need the lib.

  The script matches the name of the local file and a file on the archive overwriting the local file with the version on the archive if the first 3 flags are met and enabled.

  The script has a internal white list of extension that it will scan.
    Only extensions on the while list will be looked at by the script.
    The list is only set to with the extension of "ks" by default but more can be added by editing the code.
      Extension on the white list must only be the charters after the "." and not include the "."
        EXAMPLE: "ks" will work but ".ks" will not

    Flag 1 is extension matching, has enable/disable parameter.
      If the local file's extension is ".ks" then the file on the archive must have a extension of ".ks" not ".ksm" or ".txt".

    Flag 2 is path matching, has enable/disable parameter.
      If the local file's path is "1:/lib/" then the file on the archive must have a path of "0:/lib" not "0:/" or "0:/boot/".

    Flag 3 is size mismatching, has enable/disable parameter.
      If the local file's size is "123" then the file on the archive must not have a size of "123" but any other size will work.
      Note: the default way text files on windows computer are saved leaves you with 2 charters to note the start of a new line and kOS only has one so when coping a file kOS removes the extra charter.  This means that the size check will not work as intended because even after being copied the file on the archive will be larger than the file on the kOS core.  In most text editors designed for editing code you can set them to only use 1 charter for a new line.
     
    Flag 4 is compile from archive to local, has enable/disable parameter
      If the archive file's extension is ".ks" and the local file's extension is ".ksm" then the archive file will be compiled to the location.  Will ignore flag 1 and 3 


  Updater.ks has 4 parameters they all have defaults so the user doesn't need to always type them in every time the script is run.

    Parameter 1: extension matching enable/disable, FALSE = enable and TRUE = disable, default is FALSE
    Parameter 2:      path matching enable/disable, FALSE = enable and TRUE = disable, default is TRUE
    Parameter 3:   size mismatching enable/disable, FALSE = enable and TRUE = disable, default is TRUE
    Parameter 3:            compile enable/disable, TRUE = enable and FALSE = disable, default is FALSE


**The script Need_File.ks will scan the local volume for the file and if not found locally then it attempt to find a copy on the archive and copy it to the local volume.**
  
  The script requires the lib lib_file_util.ks and will need to have the RUNPATHONCE edited to point at the copy of the lib on the local volume or use the version called Need_File_standalone.ks as that doesn't need the lib.

  The script requires the first parameter to run.

  The script will also preserve the path of the file from the archive to the local volume.
    EXAMPLE: archive path of "0:/lib/" will result in the file being copied to "1:/lib/".

  Need_File.ks has 2 parameters and only one has a default.

    Parameter 1: the name of the file to be looked for without the extension.
      EXAMPLE: "Need_File"

    Parameter 2: the extension of the file to be looked for this is optional and defaults any extension.
      EXAMPLE: "ks" or "txt"



The lib lib_file_util.ks has its functions documented internally in comments.
