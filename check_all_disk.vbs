'
' mihaiush, 20061002
'
'    Modified Barry W. Alder 2013/09/24
'      changed code so that an error is reported if no disks are found with the /x flag
'      and an error is reported if the disk specified in the /d flag is not found
'
Set args = WScript.Arguments.Named

If (not args.Exists("w")) or (not args.Exists("c")) or args.Exists("h") Then
	WScript.Echo
	WScript.Echo "Usage: check_disk.vbs /w:INTEGER /c:INTEGER [/p] [/u:UNITS] [/h]"
	WScript.Echo "	/w: warning limit"
	WScript.Echo "	/c: critical limit"
	WScript.Echo "	/p: limits in %, otherwise in UNITS"
	WScript.Echo "	/u: B | kB | MB | GB, default MB"
	WScript.Echo "	/h: this help"
	WScript.Echo
	WScript.Echo "	check_disk.vbs /w:15 /c:5 /p /u:kB - result will be displayed in kB, limits are in percents"
	WScript.Echo
	WScript.Quit 3
End If

If args.Exists("u") Then
	u=args.Item("u")
	If u<>"B" and u<>"kB" and u<>"MB" and u<>"GB" Then
		WScript.Echo
		WScript.Echo "Units must be one of B, kB, MB, GB"
		WScript.Echo
		WScript.Quit 3	
	End If
Else
	u="GB"
End If



Select Case u
	Case "B"
		uLabel=""
		uVal=1
	Case "kB"
		uLabel="kB"
		uVal=1024
	Case "MB"
		uLabel="MB"
		uVal=1024*1024
	Case "GB"
		uLabel="GB"
		uVal=1024*1024*1024
End Select

w=1*args.Item("w")
c=1*args.Item("c")
p=args.Exists("p")

If w<c Then
	WScript.Echo
	WScript.Echo "Warning limit must be greater than critical limit"
	WScript.Echo
	WScript.Quit 3
End If
outCode=3

Const HARD_DISK = 3

strComputer = "."
Set objWMIService = GetObject("winmgmts:" _
    & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

Set colDrives = objWMIService.ExecQuery _
    ("Select * from Win32_LogicalDisk Where DriveType = " & HARD_DISK & "")
msgCritical  = ""
msgWarnning  = ""
msgOK = "All DISKS OK "
outCode=0
outPerfData = "| "
For Each  objDisk in colDrives	
 		disk=objDisk.DeviceID
 		freeSpace=objDisk.FreeSpace
 		size=objDisk.Size
 	
 					If 100*freeSpace/size<c Then
 						outCode=2
 						msgCritical= msgCritical & " " & disk & " Total: " & Round(size/uVal) & uLabel  & " - Free: " &  Round(freeSpace/uVal) & uLabel & " (" & Round(100*freeSpace/size) & "%);" 
 					End If 
 				
 						If 100*freeSpace/size<w And 100*freeSpace/size > c Then
 							outCode=1
 						msgWarnning = msgWarnning & " " & disk & " Total: " & Round(size/uVal) & uLabel  & " - Free: " &  Round(freeSpace/uVal) & uLabel & " (" & Round(100*freeSpace/size) & "%);" 

 						End If 
				
	

 		'outText=outText & " " & disk & " " & Round(freeSpace/uVal) & uLabel & " (" & Round(100*freeSpace/size) & "%);" 
 		outPerfData = outPerfData & disk & "\ Free in %=" &  Round(100*freeSpace/size) & ";" & w & ";" & c & "," 
Next

If msgCritical <> "" Then 
	outCode = 2
	outText = "DISK CRITICAL " & msgCritical
Else If msgWarnning <> "" Then 
	outCode = 1
	outText = "DISK WARNING " & msgWarnning
Else
	outCode = 0
	outText= msgOK
End If
End if
	
'Select Case outCode
'	Case 0
'		outText="All DISKS OK " & outText
'	Case 1
'		outText="DISK WARNING " & outText
'	Case 2
'		outText="DISK CRITICAL " & outText
'	Case 3
'		outCode = 2
'		outText = "ERROR! No disk found"
'End Select

WScript.Echo outText & outPerfData
WScript.Quit outCode