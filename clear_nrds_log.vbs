' Write By Yossi Bitton 
' This script will clear NRDS_Debug.log content


ON ERROR GOTO 0
Err.Clear

CONST Exit_OK = 0
CONST Exit_Warning = 1
CONST Exit_Critical = 2
CONST Exit_Unknown = 3
Const ForWriting = 2
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Nagios log file default location
logfile = "C:\Program Files\Nagios\NRDS_Win\logs\NRDS_Debug.log"

If (objFSO.FileExists(logfile)) Then
	Set objFile = objFSO.OpenTextFile(logfile, ForWriting)
	objFile.Write ""
	set objFileSize = objFSO.GetFile(logfile)
	size = objFileSize.Size
	objFile.Close
		If(size = 0) Then 	
			WScript.Echo "NRDS log file cleared successfully log size is " & size & " KB"
			WScript.Quit(Exit_OK)
		Else
			WScript.Echo "NRDS log file size is:" & size & "an error occurred while trying to clear the log file"
		    wscript.Quit(Exit_Critical)
		End if
			
Else
	WScript.Echo logfile & " doesn't exist."
	wscript.Quit(Exit_Unknown)
End If 


