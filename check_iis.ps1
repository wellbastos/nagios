<#
  .SYNOPSIS
   script for nagios to check IIS Servers Sites and AppPool.
  .DESCRIPTION
   Auther Yossi Bitton yossi@edp.co.il
   Version 1.07
   Date: 8-2016   
   Fixed: 20.12.2016
   1: Total sites ot application pools count fixed when -exclude not=$null.
   2: wrong result when using -Exclude. 
  .EXAMPLE
	.\check_iis.ps1 -CheckType Sites -Exclude site01,oldsite2 -DebugMode $true
	.\check_iis.ps1 -CheckType AppPool 
	.\check_iis.ps1  Sites
	.\check_iis.ps1  AppPool
	
	for Nagios NRPE edit NSC.ini or nsclient.ini and add the following line under section:
	[Wrapped Scripts] 
	 check_iis=check_iis.ps1 $ARG1$
	
	[Script Wrappings]
	ps1 = cmd /c echo scripts\%SCRIPT% %ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command -
	
	from nagios run:
	./check_nrpe -H <IIS IP Address> -t 30 -c check_iis -a '-CheckType Sites -Exclude site01,oldsite2' 
	or 
	./check_nrpe -H <IIS IP Address> -t 30 -c check_iis -a 'Sites site01,oldsite2' 
	
	For Test Only:
	$server = $env:COMPUTERNAME
	[System.Reflection.Assembly]::LoadFrom("C:\windows\system32\inetsrv\Microsoft.Web.Administration.dll" )
	$serverManager = [Microsoft.Web.Administration.ServerManager]::OpenRemote($server)

	$allSites = $serverManager.Sites | Select Name,ServerAutoStart,State
	$allAppPool = $serverManager.ApplicationPools  | Select Name,AutoStart,State

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
			$allAppPool = $serverManager.ApplicationPools | Select Name,State
			Print_Debug = "All Application Pools: $allAppPool"
			$allAppPool = [Array]$allAppPool
			if($allAppPool.Count -gt 0) {
				Print_Debug "Exclude list=$Exclude"
				$totalAppPool = $allAppPool.Count
				foreach($pool in $allAppPool){
					$skipPool = $False
					$AppPoolStatus = $pool.State
					$appName = $pool.Name
					$poolList += $appName + ", "
					Print_Debug "Debug: Name: $appName , Status: $AppPoolStatus"
					if($Exclude -ne $null){
						foreach($ex in $Exclude) {
							if ($appName -eq $ex) {
								$skipPool = $True
								Print_Debug "Application Pool $appName In Excluded list: $Exclude , skipping $appName ."
								break
							}
						}
					}	
					if($AppPoolStatus -ne "Started" -and $skipPool -eq $False) {
						$failedAppPool +=1;
						$descErr += "$appName, " 
					}
				}
				if($Exclude -ne $null){
					$excludeCount = $Exclude.Count
					Print_Debug "Exclude Count: $excludeCount"
					$totalAppPool-=$excludeCount
					Print_Debug "Total App Pool after exclude: $totalAppPool"
				}
				if 	($failedAppPool -gt 0) {
					$perfData = "|'Total failed Application Pools'=$failedAppPool;$totalAppPool;;$failedAppPool"
					if ($Exclude -eq $Null) {
						$desc = "Total failed Application Pools: [$failedAppPool/$totalAppPool], Name: $descErr $perfData"
					}else{
						$desc = "Total failed Application Pools: [$failedAppPool/$totalAppPool], Name: $descErr [Exclude=$Exclude] $perfData"
					}
					$retCode = $critical	
				}else{
						Print_Debug "All Application Pools are running. [$totalAppPool], Name: $poolList"
						if($Exclude -eq $Null){
							$desc = "All Application Pools are running. [$totalAppPool]"
						}else{
							$desc = "All Application Pools are running. [$totalAppPool] [Exclude=$Exclude]" 
						}
						$retCode = $ok
				}
			}else{
				$desc = "No Web Application Pools found on $server"
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
			$allSites = $serverManager.Sites | Select Name,ServerAutoStart,State
			$allSites = [Array]$allSites
			if($allSites.Count -gt 0) {
				Print_Debug "Exclude list=$Exclude"
				Print_Debug = "All Sites: $allSites"
				$totalSites = $allSites.Count
				foreach($site in $allSites){
					$skipSite = $False
					$siteStatus = $site.State
					$siteName = $site.Name
					$siteList += $siteName + ", "
					Print_Debug "Debug: Name: $siteName , Status: $siteStatus"
					if($Exclude -ne $null){
						foreach($ex in $Exclude) {
							if ($siteName -eq $ex) {
								$skipSite = $True
								Print_Debug "Site $siteName In Excluded list: $Exclude , skipping $siteName ."
								break
							}
						}
					}	
					if($siteStatus -ne "Started" -and $skipSite -eq $False) {
						$failedSites +=1;
						$descErr += "$siteName, " 
					}
				}
				if($Exclude -ne $null){
					$excludeCount = $Exclude.Count
					Print_Debug "Exclude Count: $excludeCount"
					$totalSites-=$excludeCount
					Print_Debug "Total Sites after exclude: $totalSites"
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
				$desc = "No Web Sites found on $server"
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