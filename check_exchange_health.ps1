<#
  .SYNOPSIS
   script for nagios to check Exchange Server serverhealth.
  .DESCRIPTION
   Auther Yossi Bitton yossi@edp.co.il
   Date: 11-2016   
  .EXAMPLE
	.\check_exchange_health.ps1 
	Get-ServerHealth  -Identity ocean1 -HealthSet MailboxSpace
	Get-ServerHealth -Identity ocean1
	Test-SmtpConnectivity | select Server,ReceiveConnector,StatusCode,Details
	Test-ReplicationHealth
#>

[CmdletBinding()]
Param(
	[parameter(Mandatory=$true,Position=1)] 
	[String]$ServerName,
	[parameter(Mandatory=$false,Position=2)]
	[String]$HealthName,
	[parameter(Mandatory=$false,Position=3)]
	[boolean]$DebugMode
	

)
begin {


Function Print_Debug ($msg){
	if ($DebugMode) {
		Write-Host "$msg"
	}

}

#Load_Exchange_Module
function Load_Exchange_Module() {
	Print_Debug "Load_Exchange_Module..."
	$retCode = $false
	$desc = $null
	try {
		if ((Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction:SilentlyContinue) -eq $null)
		{
			$desc = Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -PassThru
			Print_Debug "Load Status=$desc"
		}else{
			$desc = "Exchange module already loaded skipping"
		}
	}catch{
		$desc = $_.Exception.Message	
		Print_Debug $desc
		return $retCode , $desc 
	}
	if ($desc -ne $null) {
		$desc = "Exchange module loaded successful"
		Print_Debug  $desc
		$retCode = $true
	}else{
		$desc = "failed to load Exchange module"
		Print_Debug $desc
		$retCode = $false
	}
return $retCode , $desc 
}


function Test_HealthSet ($ServerName) {
	
	Print_Debug "$HealthName , $ServerName"
	$retCode = $unknowns
	try {
		$cmd = "Get-ServerHealth -Identity $ServerName | Select Identity,AlertValue ,Name,TargetResource"
		Print_Debug $cmd
		$cmdResult = Invoke-Expression $cmd
		Print_Debug "Result = $cmdResult"
		$cmdResult = [Array]$cmdResult
		if ($cmdResult.Count -gt 0) {
			$result =  $cmdResult | Where{$_.AlertValue -ne "Healthy" -And $_.AlertValue -ne "Disabled"}
			Print_Debug "result = $result"
			$result = [Array]$result
			if ($result.count -gt 0) {
				foreach ($r in $result) {
					$Identity = $r.Identity
					$TargetResource = $r.TargetResource
					$Name = $r.Name 
					$AlertValue = $r.AlertValue
					$desc += "$TargetResource $Name=$AlertValue, "
					$retCode = $critical
				}
			}else {
				$desc = "ServerHealth test completed successful"
				$retCode = $ok
			}
		}
	}catch{
		$desc = $_.Exception.Message	
		Print_Debug $desc
	}
	return $retCode , $desc
}


#Close Begin Section
}


	
process {
	$ok=0
	$warning=1
	$critical=2
	$unknown=3
	$retCode = $unknown
	
	Print_Debug "Server=$ServerName"
	Print_Debug "Warn=$Warn,Crit=$Crit"
	if ($Warn -eq $null -or $Warn -eq 0 ) {
		$Warn=30
		Print_Debug "Warn=$Warn"
	}
	if ($Crit -eq $null -or $Crit -eq 0)  {
		$Crit=100
		Print_Debug "Crit=$Crit"
	}
	
	
	# Load Exchange module
	$loadExchangeModule , $desc = Load_Exchange_Module						
	if ($loadExchangeModule -eq $true) {
		$check_status, $check_desc = Test_HealthSet $ServerName
		Print_Debug "Test_HealthSet: $check_status msg: $check_desc" 
		$desc = $check_desc
		$retCode = $check_status
	}	
Print_Debug "retCode is: $retCode"
} # Close Process Section

end {
switch ($retCode)
		
		{
			0 {$msgPrefix="OK"}
			1 {$msgPrefix="Warning"}
			2 {$msgPrefix="Critical"}
			3 {$msgPrefix="Unknown"}
				
		}	
	write-host $msgPrefix":" $desc 
	exit $retCode
}