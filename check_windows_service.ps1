<# NAME: check_windows_service.ps1
   COMMENT: The script will check if service state is running, the script get the service name.
   AUTHOR: Yossi Bitton - yossi@edp.co.il
   DATE: 19-7-2016
   
 #>
	
[CmdletBinding()]
Param(
	[parameter(Mandatory=$false,Position=1)]
	[Alias("s")]
	[string]$svcName
)
	
$OK = 0
$WARNING = 1
$CRITICAL = 2
$UNKNOWN = 3
$desc = ""


function IsServiceRunning($serviceName)
{
	$serviceStatus = Get-Service $serviceName -ErrorAction SilentlyContinue
	if ($serviceStatus -ne $null ) {
		$svcDisplayName = $serviceStatus.DisplayName
		if ($serviceStatus.StartType -ne  "Disabled") {
			if ($serviceStatus.Status -eq "Running") {
				$desc = "Service name $svcDisplayName is Running"
				return $OK, $desc 
			}else {
				$desc = "Service name $svcDisplayName is not Running!"
				return $CRITICAL , $desc
			}
		}else{
			$desc = "Service name $svcDisplayName is Disabled"
			return $OK , $desc
		}
	}else {
		$desc = "Cannot get service $serviceName, please check that service is exists"
		return $UNKNOWN,$desc
	}
}

function ValidateParameters($serviceName)
{
	if ($serviceName -eq $null -or $serviceName -eq ""){
		 $desc = "service name argument is missing!, usage:  ./check_win_service.ps1 service_name `n" 
		 return $UNKNOWN,$desc
	}
$desc = "All parameters are OK, continue..."
return $true,$desc	
}

function Main()
{
	$paramCheck,$paramDesc = ValidateParameters($svcName)
	if ($paramCheck -eq $true) {
		$status,$desc =  IsServiceRunning($svcName)
	}else {
		$desc = $paramDesc
		$status = $UNKNOWN
	}
	Write-Host $desc
	exit $status
}

# We Start here, and we Call to main function 
Main