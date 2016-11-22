<#
  .SYNOPSIS
   plugin for nagios to check Exchange Server 2007,2010,2013.
  .DESCRIPTION
   Auther Yossi Bitton yossi@edp.co.il
   Date: 8-2016   
  .EXAMPLE
	to get all exchange db status:
	.\check_exchange.ps1 -CheckType DBStatus -ExchangeVer 2013
	.\check_exchange.ps1 DBStatus 2013
	
	to check the queue 
	.\check_exchange.ps1 -CheckType Queue -ExchangeVer 2013 -Warn 10 -Crit 50 -DebugMode $true 
	this command also works, using args position:
	.\check_exchange.ps1  Queue 2013 10 50 $false 
	
	for Nagios NRPE edit NSC.ini or nsclient.ini and add the following line under section:
	[Wrapped Scripts] 
	 check_exchange=check_exchange.ps1 $ARG1$
	
	[Script Wrappings]
	ps1 = cmd /c echo scripts\%SCRIPT% %ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command -
	 
	 
#>

[CmdletBinding()]
Param(
	[parameter(Mandatory=$true,Position=1)] 
	[ValidateSet("DBStatus", "Queue")] 
	[String]$CheckType ,
	[parameter(Mandatory=$true,Position=2)] 
	[ValidateSet("2007" , "2010", "2013")] 
	[String]$ExchangeVer ,
	[parameter(Mandatory=$false,Position=3)]
	[int]$Warn ,
	[parameter(Mandatory=$false,Position=4)]
	[int]$Crit ,
	[parameter(Mandatory=$false,Position=5)]
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
		switch($ExchangeVer)
		{
			"2007" 
			{
				if ((Get-PSSnapin -Name  Microsoft.Exchange.Management.PowerShell.Admin -ErrorAction:SilentlyContinue) -eq $null)
				{
					$desc = Add-PSSnapin Microsoft.Exchange.Management.PowerShell.Admin -PassThru
				}else{
					$desc = "Exchange module already loaded skipping"
				}
			}
			"2010"
			{
				if ((Get-PSSnapin -Name "Microsoft.Exchange.Management.PowerShell.E2010" -ErrorAction:SilentlyContinue) -eq $null)
				{
					$desc = Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010 -PassThru
				}else{
					$desc = "Exchange module already loaded skipping"
				}
			}
			"2013"
			{
				if ((Get-PSSnapin -Name Microsoft.Exchange.Management.PowerShell.SnapIn -ErrorAction:SilentlyContinue) -eq $null)
				{
					$desc = Add-PSSnapin Microsoft.Exchange.Management.PowerShell.SnapIn -PassThru
				}else{
					$desc = "Exchange module already loaded skipping"
				}
			}
		}
		Print_Debug "Load Status=$desc"
		
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

Function Get_Queue_Status () {
	$retCode = $unknown
	$desc = ""
	$perfData = ""
	$toatalQueue = 0
	try {
		$queueCount = Get-Queue -Server $server | where{$_.MessageCount -gt 0}| select Identity , MessageCount
		Print_Debug "Queue found on server $server = $queueCount"
		if ($queueCount -ne $null) {
			foreach ($q in $queueCount) {
				$qCount = $q.MessageCount
				$toatalQueue += $qCount
				if($qCount -gt $Crit) {
					$retCode = $critical
				}elseif ($qCount -gt $Warn)
				{
					if ($retCode -ne $critical) {
						$retCode = $warning
					}
				}elseif ($retCode -ne $critical -and $retCode -ne $warning)
				{
						$retCode = $ok
				}
			Print_Debug "Current retCode is: $retCode"
			$desc += "$($q.Identity) Queue Count: $($q.MessageCount) "	
			}
			
		}else{
			$desc = "Exchange queue is empty."
			$retCode = $ok
		}
	}catch{
		$desc = $_.Exception.Message	
		Print_Debug $desc
	}
	$perfData = "|'Message Queue'=$toatalQueue;$Warn;$Crit;$toatalQueue"
	return $retCode , "$desc$perfData"
}


Function Get_DataBase_Status () {
	$retCode = $unknown
	try {
		$dblist = Get-MailboxDatabase -Status | Where {$_.MountAtStartup -eq $true} | Select Name,Mounted
		if ($dblist -ne $null) {
			$totalDB = $dblist.Count 
			$mountedDb = $dblist | Where {$_.Mounted -eq $true} | Select Name
			$notMountedDb = $dblist | Where {$_.Mounted -eq $false} | Select Name
			if ($notMountedDb -eq $null) {
				$totalMountedDb = $mountedDb.Count
				$mountedDbName = $mountedDb.Name
				$retCode = $ok
				$desc = "All Exchange DB are mounted [$mountedDbName] [$totalDB\$totalMountedDb]"
			}else {
				$totalNotMountedDb = $notMountedDb.Count
				$retCode = $critical
				$desc = "The $notMountedDb are not mounted [$totalNotMountedDb\$totalDB] "
			}
		}else {
			$desc = "No database found on server"
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
	$server = $env:COMPUTERNAME
	
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
		Switch($CheckType) {
			"DBStatus" 
			{
				$check_status, $check_desc = Get_DataBase_Status 
				Print_Debug "Get_DataBase_Status: $check_status msg: $check_desc" 
			}
			"Queue"
			{
				$check_status, $check_desc = Get_Queue_Status 
				Print_Debug "Get_Queue_Status: $check_status msg: $check_desc" 
			}
		}
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