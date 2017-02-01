<# NAME: Start_Stop_Process.ps1
COMMENT: nagios plugin to start or stop processes.
the script get 3 arguments $action $Path $fileName, the script validate the params
and path to file, and acording to $action (start or stop ) the script run StartProcess or StopProcess function
DATE: 29-7-2015
 #>

[CmdletBinding()]
Param(
	[parameter(Mandatory=$true,Position=1)]
	[string]$action,
	
	[parameter(Mandatory=$true,Position=2)]	
	[string]$Path,
	
	[parameter(Mandatory=$false,Position=3)]	
	[string]$USERNAME,
	
	[parameter(Mandatory=$false,Position=4)]	
	[string]$PASSWORD,
	
	[parameter(Mandatory=$false,Position=5)]
	[string]$Verbos
)

#$LOG_FILE = ".\log_start_stop_process.txt"
$OK = 0
$WARNING = 1
$CRITICAL = 2
$UNKNOWN = 3

$desc = ""

function WriteLog ($message)
{
	$date = get-date
	$desc = "info: $date $message"
	Add-Content -Encoding UTF8 $LOG_FILE $desc
}
$Verbos = $true
#check if $path exists, and $action is valid actions,and all parameters is ok 
function ValidateParameters()
{
	<# if($Verbos -eq $true){	
		WriteLog ("*" * 80)
		WriteLog ("Got the following parameters:") 
		WriteLog ("action=$action, Path=$Path, file name = $fileName")
	} #>	
	if ($action -ne "start" -and $action -ne "stop"){
		 $desc = "$action ,is not valid, valid actions is: start or stop `n" 
		 return $false,$desc
	}
	if((Test-Path -Path  $Path) -ne $True){
		$desc = "$Path does not exist `n"
		return $false,$desc
	}
	$isFile = Split-Path $Path -leaf
	if(-not ($isFile.Contains("."))){
		$desc = "$isFile is not valid file"
		return $false,$desc
	if($USERNAME -eq $null -or $PASSWORD -eq $null) {
		$desc = "user name and password parameters required"
		return $false,$desc
	}
}

# if all parameters is OK.	
$desc = "All parameters are OK, continue..."
return $true,$desc
}	
			   
function StartProcess($processName)
{
	$startResult,$processID = IsProcessRunning($processName)
	if($startResult -eq $true) {
		$desc = "OK: Process $processName already running, processID is: " + $processID.id
		return $true,$desc
		
	}else{
			Start-Process -FilePath  $Path  -NoNewWindow
			$startResult,$processID = IsProcessRunning($processName)
			if ($startResult -eq $true){
					$desc = "OK: $processName started successfully, process ID is: " + $processID.id 
					return $startResult,$desc
			}else{
				$desc = "Failed to start $processName" 
					return $startResult,$desc
			}
		}
}

function StopProcess($processName)
{	
	$startResult,$processID = IsProcessRunning($processName)
	Try {
				if($startResult -eq $true -or $startResult -eq $array) {
					Stop-Process -Name $processName -Force
					#wait to all processes closed
					sleep 1
					$stopResult,$processID = IsProcessRunning($processName)
					if($stopResult -eq $true){
						$desc = "CRITICAL: can't stop process $processName"
						return $false,$desc
					}else{	
						$desc = "OK: process $processName successfully stopped"
						return $true,$desc		
					}
				}else{
					$desc = "OK: process $processName already stopped"
					return $true,$desc
				}
		}Catch{
			$desc = "CRITICAL: can't stop process $processName"
					return $false,$desc
		}
}
			
function CreateTaskScheduler ($processName)
{
	$startResult,$processID = IsProcessRunning($processName)
	if($startResult -eq $true) {
		$desc = "OK: Process $processName already running, processID is: " + $processID.id
		return $true,$desc
	}
	
	$TaskName = "start_" + $processName + "_process"
	$TaskDescr = "Task created by Nagios Monitoring System"
	$TaskCommand = $Path
	$WorkingDirectory = (Get-Item $Path).DirectoryName
	$CreateOrUpdate = 6 # 6 == Task Create or Update
	try {
		$service = new-object -ComObject("Schedule.Service")
		$service.Connect()
		#$service.Connect($null,$USERNAME,$null,$PASSWORD)
		$rootFolder = $service.GetFolder("\")
		$TaskDefinition = $service.NewTask(0) 
		$TaskDefinition.RegistrationInfo.Description = "$TaskDescr"
		$TaskDefinition.Settings.Enabled = $true
		$Action = $TaskDefinition.Actions.Create(0)
		$Action.Path = "$TaskCommand"
		$Action.WorkingDirectory = "$WorkingDirectory"
		$registerTaskStatus = $rootFolder.RegisterTaskDefinition($TaskName,$TaskDefinition,$CreateOrUpdate,$null,$null,3)
		if ($registerTaskStatus.Name -eq $TaskName) {
			$createdTask = $rootFolder.GetTask($TaskName)
			if($createdTask.Name -eq $TaskName) {
				$startTaskStatus = $createdTask.Run(0)
				if($startTaskStatus -ne $null) { 			# 4 = Running
					# check if process is running loop 5 times until process completed to start
					foreach($i in 1..5){
						$processStatus,$processID = IsProcessRunning($processName)
						if ($processStatus -eq $true) {
							break
						}else{
							sleep 1
						}
					}
					if ($processStatus -eq $true){
							$desc = "OK: $processName started successfully, process ID is: " + $processID.id 
					}else{
							$desc = "Failed to start $processName" 
					}
					try {
						 $RootFolder.DeleteTask($TaskName,0)
						 return $processStatus,$desc
					}Catch [System.Exception]{
						return $processStatus , "Exception Returned when trying to delete task $TaskName"
					}
					
				}
			}
		}else{
			return $false , "an error has occurred when trying to create Task Schedule for $processName "
		}
			
	}Catch [System.Exception]{
		return $false ,"Exception Returned: cannot connect to Schedule service"
	}
}
			
function IsProcessRunning($processNameToCheck)
{
	$processID = Get-Process $processNameToCheck -ErrorAction SilentlyContinue
	if($processID.count -gt 0 -or $processID -ne $null){
			return $true,$processID
	}else{
		return $false,$processID
		}
}	
   
function Main()
{
	$paramCheck,$paramDesc = ValidateParameters
	<# if($Verbos -eq $true){	
		WriteLog ("Parameters are OK? $paramCheck Description: $paramDesc")
	} #>
	if ($paramCheck -eq $true)
	{
		$processName = (Get-Item $Path).BaseName
			if($action -eq "start") {
				$startStatus ,$desc = CreateTaskScheduler($processName)
			}elseif ($action -eq "stop"){
				$startStatus,$desc = StopProcess($processName)
			}
	}else{
		write-Host "failed to validate arguments, $paramDesc"
		exit $UNKNOWN
	}	

	 if($startStatus -eq $true)
		{
			Write-Host $desc
			exit $OK
		}else{
			Write-Host $desc
			exit $CRITICAL
		} 
}

# We Start here, and we Call to main function 
Main


