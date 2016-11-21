<#
  .SYNOPSIS
   script for nagios to check IIS Servers Sites and AppPool.
  .DESCRIPTION
   Auther Yossi Bitton yossi@edp.co.il
   Date: 8-2016   
  .EXAMPLE
	.\check_iis.ps1 -CheckType Sites -Exclude site01,oldsite2 -$DebugMode $true
	.\check_iis.ps1 -CheckType AppPool 
	.\check_iis.ps1  Sites
#>

[CmdletBinding()]
Param(
	[parameter(Mandatory=$true,Position=1)] 
	[ValidateSet("Sites", "AppPool")] 
	[String]$CheckType ,
	[parameter(Mandatory=$false,Position=2)]
	[int]$warn ,
	[parameter(Mandatory=$false,Position=3)]
	[int]$crit ,
	[parameter(Mandatory=$false,Position=4)]
	[boolean]$DebugMode , 
	[parameter(Mandatory=$false,Position=5)]
	[String[]]$Exclude
	

)
begin {


Function Print_Debug ($msg){
	if ($DebugMode) {
		Write-Host "$msg"
	}

}

#Load_Exchange_Module
function Load_IIS_Module() {
	Print_Debug "Load_IIS_Module..."
	$retCode = $false
	try {
			$desc = [System.Reflection.Assembly]::LoadFrom("C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll" )
			Print_Debug "Load Status=$desc"
	}catch{
		$desc = $_.Exception.Message	
		Print_Debug $desc
	}
	if ($desc -ne $null) {
		$desc = "IIS module loaded successful"
		Print_Debug  $desc
		$retCode = $true
	}else{
		$desc = "failed to load IIS module"
		Print_Debug $desc
		$retCode = $false
	}
return $retCode , $desc 
}

Function Get_AppPool_Status () {
	$retCode = $unknowns
	$desc = $null
	$perfData = ""
	$failedAppPool = 0
	$descErr = $Null
	$poolList = $Null
	try {
		$serverManager = [Microsoft.Web.Administration.ServerManager]::OpenRemote($server)
		if ($serverManager -ne $null) {
			Print_Debug "Connected to $serverManager"
			$allAppPool = $serverManager.ApplicationPools | Where {$_.AutoStart -eq $True } | Select Name,AutoStart,State
			$allAppPool = [Array]$allAppPool
			if($allAppPool.Count -gt 0) {
				$totalAppPool = $allAppPool.Count
				foreach($pool in $allAppPool){
					$skipPool = $False
					$AppPoolStatus = $pool.State
					$appName = $pool.Name
					$poolList += $appName + ", "
					Print_Debug "Debug: Name: $appName , Status: $AppPoolStatus"
					if($Exclude -ne $null){
						Print_Debug "Exclude list=$Exclude"
						foreach($ex in $Exclude) {
							if ($appName -eq $ex) {
								$skipPool = $True
								break
							}
						}
					}	
					Print_Debug "skipPool = $skipPool"
					if($AppPoolStatus -ne "Started" -and $skipPool -eq $False) {
						$failedAppPool +=1;
						$descErr += "$appName, " 
					}
				}
				if 	($failedAppPool -gt 0) {
					$perfData = "|'Total failed ApplicationPools'=$failedAppPool;$totalAppPool;;$failedAppPool"
					if ($Exclude -eq $Null) {
						$desc = "Total failed ApplicationPools: [$failedAppPool/$totalAppPool], Name: $descErr $perfData"
					}else{
						$desc = "Total failed ApplicationPools: [$failedAppPool/$totalAppPool], Name: $descErr [Exclude=$Exclude] $perfData"
					}
					$retCode = $critical	
				}else{
						Print_Debug "All ApplicationPools are running. [$totalAppPool], Name: $poolList"
						if($Exclude -eq $Null){
							$desc = "All ApplicationPools are running. [$totalAppPool]"
						}else{
							$desc = "All ApplicationPools are running. [$totalAppPool] [Exclude=$Exclude]" 
						}
						$retCode = $ok
				}
			}else{
				$desc = "No Web ApplicationPools found on $server with autostart"
				$retCode = $ok
			}
		}else{
			$desc = "An error occurred when trying to connect to the iis servers."
			$retCode = $unknown
		}
	}catch{
		$desc = $_.Exception.Message	
		Print_Debug $desc
	}
	return $retCode , $desc
}


Function Get_Sites_Status () {
	$retCode = $unknowns
	$desc = $null
	$perfData = ""
	$failedSites = 0
	$descErr = $Null
	$siteList = $Null
	try {
		$serverManager = [Microsoft.Web.Administration.ServerManager]::OpenRemote($server)
		if ($serverManager -ne $null) {
			Print_Debug "Connected to $serverManager"
			$allSites = $serverManager.Sites | Where {$_.ServerAutoStart -eq $True } | Select Name,ServerAutoStart,State
			$allSites = [Array]$allSites
			if($allSites.Count -gt 0) {
				$totalSites = $allSites.Count
				foreach($site in $allSites){
					$skipSite = $False
					$siteStatus = $site.State
					$siteName = $site.Name
					$siteList += $siteName + ", "
					Print_Debug "Debug: Name: $siteName , Status: $siteStatus"
					if($Exclude -ne $null){
						Print_Debug "Exclude list=$Exclude"
						foreach($ex in $Exclude) {
							if ($siteName -eq $ex) {
								$skipSite = $True
								break
							}
						}
					}	
					Print_Debug "skipSite = $skipSite"
					if($siteStatus -ne "Started" -and $skipSite -eq $False) {
						$failedSites +=1;
						$descErr += "$siteName, " 
					}
				}
				if 	($failedSites -gt 0) {
					$perfData = "|'Total failed sites'=$failedSites;$totalSites;;$failedSites"
					if ($Exclude -eq $Null) {
						$desc = "Total failed sites: [$failedSites/$totalSites], Name: $descErr $perfData"
					}else{
						$desc = "Total failed sites: [$failedSites/$totalSites], Name: $descErr [Exclude=$Exclude] $perfData"
					}
					$retCode = $critical	
				}else{
						Print_Debug "All Web Sites are running. [$totalSites], Name: $siteList"
						if($Exclude -eq $Null){
							$desc = "All Web Sites are running. [$totalSites]"
						}else{
							$desc = "All Web Sites are running. [$totalSites] [Exclude=$Exclude]" 
						}
						$retCode = $ok
				}
			}else{
				$desc = "No Web Sites found on $server with autostart"
				$retCode = $ok
			}
		}else{
			$desc = "An error occurred when trying to connect to the iis servers."
			$retCode = $unknown
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
	
	if ($warn -eq $null) {$warn=10}
	if ($crit -eq $null) {$warn=50}
	
	# Load IIS module
	$loadIISModule , $desc = Load_IIS_Module						
	if ($loadIISModule -eq $true) {
		Switch($CheckType) {
			"Sites" 
			{
				$check_status, $check_desc = Get_Sites_Status 
				Print_Debug "Get_Sites_Status: $check_status msg: $check_desc" 
			}
			"AppPool"
			{
				$check_status, $check_desc = Get_AppPool_Status 
				Print_Debug "Get_AppPool_Status: $check_status msg: $check_desc" 
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