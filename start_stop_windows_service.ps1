<# NAME: start_windows_service.ps1
COMMENT: nagios plugin to start service.
the script get 2 arguments $action start or stop and $serviceName and try to start or stop the service.
DATE: 6-8-2015
Author: Yossi Bitton
 #>

[CmdletBinding()]
Param(
	[parameter(Mandatory=$true,Position=1)]
	[string]$action,
	
	[parameter(Mandatory=$true,Position=2)]	
	[string]$serviceName,
	
	[parameter(Mandatory=$false,Position=3)]
	[string]$Verbos
)

$OK = 0
$WARNING = 1
$CRITICAL = 2
$UNKNOWN = 3
$LOG_FILE = ".\log_start_stop_windows_service.txt"
$desc = ""

function ValidateParameters()
{
	if ($action -ne "start" -and $action -ne "stop"){
		 $desc = "The $action is not valid action!, valid actions is: start or stop `n" 
		 return $false,$desc
	}
	if ($serviceName -eq $null){
		 $desc = "service name argument is missing!, usage:  ./start_windows_service.ps1 <start / stop> service_name `n" 
		 return $false,$desc
	}
	if((Get-Service $serviceName -ErrorAction SilentlyContinue) -eq $null){
		$desc = "The service $serviceName does not exists"
		return $false,$desc
	}
# if all parameters is OK.	
$desc = "All parameters are OK, continue..."
return $true,$desc	
}

function WriteLog ($message)
{
	$date = get-date
	$desc = "info: $date $message"
	Add-Content -Encoding UTF8 $LOG_FILE $desc
}

function StartService ($serviceName)
{
	if(IsServiceRunning($serviceName) -eq $true) {
		$desc = "OK: service $serviceName already running"	
		return $true,$desc
	}else{
		$startStatus = Start-Service -Name $serviceName -PassThru -ErrorAction SilentlyContinue
		if ($startStatus -ne $null -and $startStatus.Status -eq "Running") {
			$desc = "OK: The service $serviceName was started successfully"
			return $true,$desc
		}else{
			$desc = "Failed to start $serviceName service, check that the service status is not disabled" 
			return $false,$desc
		}
	}
$desc = "an error has occurred while trying to start the service $serviceName"
return $false
}

function StopService ($serviceName)
{
	$serviceStatus = IsServiceRunning($serviceName)
	if($serviceStatus -eq $false) {
		$desc = "OK: Service $serviceName is already stopped"	
		return $true,$desc
	}else{
		$stopStatus = Stop-Service -Name $serviceName -PassThru -ErrorAction SilentlyContinue
		if ($stopStatus -ne $null -and $stopStatus.Status -eq "Stopped") {
			$desc = "OK: The service $serviceName was stopped successfully"
			return $true,$desc
		}else{
			$desc = "Failed to stop service $serviceName ,please check that the service can stop" 
			return $false,$desc
		}
	}
$desc = "an error has occurred while trying to stop the service $serviceName"
return $false
}

function IsServiceRunning($serviceName)
{
	$serviceStatus = Get-Service $serviceName -ErrorAction SilentlyContinue
	if ($serviceStatus.Status -eq "Running") {
		return $true
	}elseif($serviceStatus.Status -eq "Stopped"){
		return $false
	}
return $false
}

function Main()
{
	$paramCheck,$paramDesc = ValidateParameters
	if($Verbos -eq $true){	
		WriteLog ("Parameters are OK? $paramCheck Description: $paramDesc")
	}
	if ($paramCheck -eq $true)
	{
		if($action -eq "start") {
				if($Verbos -eq $true){WriteLog  "Got command start with arguments: $paramDesc" }	
				$startStatus,$desc = StartService($serviceName)
				if($Verbos -eq $true){	WriteLog ("Is Service started: $startStatus, $desc")}
				
			}elseif ($action -eq "stop"){
				
				if($Verbos -eq $true){WriteLog  "Got command stop with arguments: $paramDesc"}
				$startStatus,$desc = StopService($serviceName)
				if($Verbos -eq $true){WriteLog ("Is Service is stopped: $startStatus $desc")}
			}
	}else{
		write-Host "Failed to validate arguments: $paramDesc"
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