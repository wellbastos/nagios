# Script name:   	check_stuck_tasks.ps1
# Version:			1.0.0
# Created on:    	28/1/2015																			
# Author:        	Yossi  Bitton

# for nagiosxi:	command[Scheduled Task Status] = $PLUGIN_DIR$\check_stuck_tasks.ps1

# the script will run only between 06:00 to 20:00
# check if current hour is before 6:00 or after 20:00
$CurrentHour = (get-date).Hour
if (!($CurrentHour -gt 6 -and $CurrentHour -lt 20)) {
	write-host "The script run only between 06:00 to 20:00, the script will exit."
	exit 0
	}	
	
	
# Set new line Environment
$nl = [Environment]::NewLine
$tasks = @()

$path="\"

# Try connecting to schedule service COM object
try {
	$schedule = New-Object -ComObject "Schedule.Service" 
}catch {
		Write-Host "UNKNWON: Schedule.Service COM Object not found, this script requires this object"
		Exit 3 }
	
$schedule.Connect()
$exitCode = 0

function Get-AllTaskSubFolders {
    [cmdletbinding()]
    param (
        # Set to use $Schedule as default parameter so it automatically list all files
        # For current schedule object if it exists.
        $FolderRef = $Schedule.getfolder("\")
    )
	if ($RootFolder) {
        #$FolderRef
    } else {
    #$subTasks = $null
        #$FolderRef
        $ArrFolders = @()
        if(($folders = $folderRef.getfolders(1))) {
            foreach ($folder in $folders) {
                $ArrFolders += $folder
                if($folder.getfolders(1)) {
                    Get-AllTaskSubFolders -FolderRef $folder 
                }
            }
		
        }
		
	}
return $FolderRef
}
	
#write-host $ArrFolders
function CheckSubFoldersTasks {
		$AllFolders = Get-AllTaskSubFolders
		foreach($f in $AllFolders) {
			$taskLists = $schedule.GetFolder($f.path).GetTasks(0) | select Name,State,Enabled,LastRunTime,LastTaskResult,NumberOfMissedRuns,NextRunTime
			foreach ($task in $taskLists) {
					if ($task.State -eq 4 -and $task.name -like "yahav*"){
						$varDate = Get-date
						$varLastRunTime = $task.LastRunTime
						if($varDate -gt $varLastRunTime) {
							$RunningTime = $varDate - $varLastRunTime
								$TotalRun = [int]$RunningTime.TotalMinutes
								if ($TotalRun -gt 15) {
										$subTasks = $subTasks +  "Task Name: " + $task.name + " in folder "  + $f.path +  " running for: " + $TotalRun + " Minutes " + $nl
										
								}
						}	
					}
			}
		}
	return $subTasks
}



$Total = CheckSubFoldersTasks
	if ($Total) {
		write-host $Total
		exit 2
	}else{
		write-host "All tasks status running in normal time" 
		exit 0
	}
		
	
