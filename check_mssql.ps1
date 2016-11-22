<#
  .SYNOPSIS
   script for nagios to check SQL DataBases , Connection Time, Jobs.	
  .DESCRIPTION
   Auther Yossi Bitton yossi@edp.co.il
   Date: November 2016   
  .EXAMPLE
	.\check_mssql.ps1 
   version 1.0.4	
	
   for Nagios NRPE edit NSC.ini or nsclient.ini and add the following line under section:
	[Wrapped Scripts] 
	 check_mssql=check_mssql.ps1 $ARG1$
	
	[Script Wrappings]
	ps1 = cmd /c echo scripts\%SCRIPT% %ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command -
	
	from nagios run:
	./check_nrpe -H <MSSQL IP Address> -c check_mssql -a '-CheckType DBStatus -Exclude DB01,DB03' 
	or 
	./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'DBStatus'
	./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'ConTime'
	./check_nrpe -H <MSSQL IP Address> -c check_mssql -a 'Jobs'
	if no instance specify the script check the default instance (COMPUTERNAME)
	to monitor specify instance add -InstanceName <Instance Name>.	
#>

[CmdletBinding()]
Param(
	[parameter(Mandatory=$true,Position=1)] 
	[ValidateSet("DBStatus", "ConTime", "Jobs")] 
	[String]$CheckType ,
	[parameter(Mandatory=$false,Position=2)]
	[String[]]$InstanceName  ,
	[parameter(Mandatory=$false,Position=3)]
	[boolean]$DebugMode ,
	[parameter(Mandatory=$false,Position=4)]
	[String[]]$Exclude
)
begin {


Function Print_Debug ($msg){
	if ($DebugMode) {
		Write-Host "$msg"
	}

}
	
#Connect to sql server 
function Connect_To_Sql ($instance) {
	Print_Debug "Function:	Connect_To_Sql."
	$retCode = $false
	$sqlObj = ""
	try {
		Print_Debug "Trining to connect to $instance ..."
		$sqlObj = New-Object "Microsoft.SqlServer.Management.Smo.Server" $instance
		if($sqlObj.Version -ne $null -or $sqlObj.Databases -ne $null )  {
			$desc = "Connecting to SQL server $instance completed"
			$retCode = $true
		}else {
			$desc = "Failed to Connect to SQL server $instance"	
		}
	}catch{
		$desc = $_.Exception.Message	
		Print_Debug $desc
	}
Print_Debug $desc
return $retCode, $desc , $sqlObj 
	
}
	

#Connect to sql server 
	function SQL_Connection_Time ($instance) {
		Print_Debug "SQL_Connection_Time..."
		$retCode = $unknown
		$desc = "an error has occurred when trying to connect to the SQL server"
		$perfData = ""
		try {
			$connTime = (Measure-Command { $sqlObj = New-Object "Microsoft.SqlServer.Management.Smo.Server"  $instance}).totalseconds 
		}catch{
			$desc = $_.Exception.Message	
			Print_Debug $desc
		}
		
		$sqlVersion =  $sqlObj.Version
		if($sqlObj.Version -ne $null -or $sqlObj.Databases -ne $null ) {
			$perfData = "|'Connect Time'=" + $connTime + ";$timeToConnectWarn;$timeToConnectCrit;$connTime"
			if ($connTime -lt $timeToConnectWarn) {
				$desc = "$instance Connect time=$connTime seconds, Version $sqlVersion"
				$retCode = $ok
			}elseif ($connTime -gt $timeToConnectCrit){
				$desc = "$instance Connect took too long, time=$connTime seconds, Version $sqlVersion"
				$retCode = $critical
			}elseif ($connTime -lt $timeToConnectCrit -and $connTime -gt $timeToConnectWarn ){
				$desc = "$instance Connect took too long, time=$connTime seconds, Version $sqlVersion"
				$retCode = $warning
			}
		}else {
			$desc = "Failed to Connect to SQL server $instance [$connTime seconds]"
			$retCode = $critical
		}
	
return $retCode, "$desc$perfData"
	}

# Load SQL power shell module	
	function Load_Sql_Smo () {
	Print_Debug "Function: Load_Sql_Smo. "
	$retCode = $false
	$desc = ""
	try {
		if ([System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")){
			$retCode = $true
			$desc = "SMO module load successful" 
		}
	}catch {
		$desc = $_.Exception.Message
	}
	Print_Debug $desc
	return $retCode , $desc
}

#Get SQL jobs status 
	function Get_Jobs_Status($sqlObj) {
		$retCode = $unknown
		$desc = "an error has occurred when trying to get sql jobs"
		$totalJobCount = $sqlObj.JobServer.Jobs.Count;
		if ($totalJobCount -gt 0){
			$failedCount = 0;
			$successCount = 0;
			# loop in all jobs to check last status
			$totalJobCount =0
			$desc = $null
			foreach($job in $sqlObj.JobServer.Jobs)
			{
				$skipJob = $False
				$jobName = $job.Name;
				$jobEnabled = $job.IsEnabled;
				$LastRunDate = $job.LastRunDate
				$jobLastRunOutcome = $job.LastRunOutcome;
				$HasSchedule = $job.HasSchedule
				if($jobEnabled -eq $true -and $HasSchedule -eq $True) {
					$totalJobCount+=1
					if($Exclude -ne $null){
						Print_Debug "Exclude list=$Exclude"
						foreach($ex in $Exclude) {
							if ($jobName -eq $ex) {
								$skipJob = $True
								break
							}
						}
					}	
					
					# if job failed count failed jobs
					if($jobLastRunOutcome -eq "Failed" -and $skipJob -eq $False ){
						$failedCount += 1;
						$desc += "Job: $jobName=$jobLastRunOutcome Date: $LastRunDate. " 
					}elseif($jobLastRunOutcome -eq "Succeeded") {
						$successCount += 1;
					}
				}else 
				{
					Print_Debug "Job $jobName HasSchedule = $HasSchedule "
				}
			}
			# Found failed job/s
			if 	($failedCount -gt 0) {
				$desc = "Total failed: $failedCount. $desc"
				$retCode = $critical 
			}else{
				if($Exclude -ne $Null) {
					$desc = "All SQL jobs are completed successful, Total:($successCount) [Excluded Jobs: $Exclude]"
				}else{
					$desc = "All SQL jobs are completed successful, Total:($successCount)"
				}		
				$retCode = $ok 
			}
		}else{
			$desc = "No jobs found in SQL server $sqlObj"
			$retCode = $ok
		}
	return $retCode , $desc
	}

# Check if all Databases are in on line mode. 	
	function Get_DataBase_Status ($sqlObj , $instance) {
	Print_Debug "Function: Get_DataBase_Status"
	$retCode = $unknown
	$desc = ""
	$failedDBCount = 0;
	$successDBCount = 0;
	$totalDb = $sqlObj.Databases.Count
	foreach($db in $sqlObj.Databases)
	{
		$skipDB = $False
		$dbStatus = $db.Status
		$dbName = $db.Name
		if($Exclude -ne $null){
			Print_Debug "Exclude list=$Exclude"
			foreach($ex in $Exclude) {
				if ($dbName -eq $ex) {
					$skipDB = $True
					break
				}
			}
		}	
		Print_Debug "SkipDB = $SkipDB"
		if($dbStatus -ne "Normal" -and $skipDB -eq $False) {
			$failedDBCount +=1;
			$desc += "$dbName Is: $dbStatus.`n" 
		}
	}
	if 	($failedDBCount -gt 0) {
		$desc = "$instance Total failed: $failedDBCount/$totalDb $desc "
		if ($Exclude -ne $null) {
			$desc = "$instance Total failed: $failedDBCount/$totalDb $desc "
		}
		$retCode = $critical
	}else{
		if($Exclude -ne $Null) {
			$desc = "$instance All Databases are online. [Total DataBases: $totalDb] [Excluded DB: $Exclude]"
		}else{
			$desc = "$instance All Databases are online. [Total DataBases: $totalDb]"
		}		
		$retCode = $ok
	}
	Print_Debug $desc	
	return $retCode , $desc	
	}

#Close End Section
}


	
process {
	$ok=0
	$warning=1
	$critical=2
	$unknown=3
	$retCode = $unknown
	$Server = $env:COMPUTERNAME
	$timeToConnectCrit=5
	$timeToConnectWarn=3

	$AllInstance = @()
	if ($InstanceName -ne $null) {
		$InstanceNameReplaced = $InstanceName -Replace(' ' , '')
		Print_Debug $InstanceNameReplaced
		foreach ($ins in $InstanceNameReplaced) {
			Print_Debug $ins
			$AllInstance +="$Server\$ins" 
		 }
	}else{
		$AllInstance += $Server
	}
	
	Print_Debug $AllInstance
	Print_Debug $AllInstance.Count
	
	# Load SQL module
	$smoLoad , $desc = Load_Sql_Smo						
	if ($smoLoad -eq $true) {
		$TotalInstance = $AllInstance.Count
		Print_Debug "TotalInstance=$TotalInstance"
		$TotalOkFound = 0 
		Print_Debug "TotalOkFound=$TotalOkFound"
		$i = 0
		foreach($instance in $AllInstance){	
			$i +=1
			Print_Debug  "Current Instance is: $i : $instance" 
			$sqlConn ,$desc ,$sqlObj = Connect_To_Sql $instance   
			if ($sqlConn -eq $true) {
				$desc = $null
				Switch($CheckType) {
					"DBStatus" 
					{
						$check_status, $check_desc = Get_DataBase_Status $sqlObj $instance
						Print_Debug "Current Instance Name=$check_desc"
						$sum_cehck_desc += "$check_desc`n"
						Print_Debug "Status of $instance is $check_desc"
					}
					"ConTime" 
					{
						$check_status ,$check_desc = SQL_Connection_Time $instance
						Print_Debug "ConTime=$check_status, Status=$check_desc"
						$sum_cehck_desc += "$check_desc`n"
						Print_Debug "Status of $instance is $check_desc"
					}
					"Jobs"
					{
						$check_status ,$check_desc  = Get_Jobs_Status $sqlObj
						Print_Debug "ConTime=$check_status, Status=$check_desc"
						$sum_cehck_desc += "$check_desc`n"
						Print_Debug "Status of $instance is $check_desc"
					}
				}
				if($check_status -eq $ok) {
					$TotalOkFound +=1
					Print_Debug "Total Ok Found =$TotalOkFound"
				}else{
					$sum_cehck_desc  += "$check_desc`n"
				}
			}else {
				$sum_cehck_desc += "$desc`n"
			}
			
		}
		
		Print_Debug "Total Instance OK: $TotalOkFound/$TotalInstance"
		if($TotalOkFound -eq $TotalInstance) { 
			Print_Debug "Total Ok Instance is equal to Total Instance, Exit OK"
			$desc = $sum_cehck_desc
			$retCode = $ok
		}else{
			Print_Debug "Total Ok Instance is NOT equal to Total Instance, Exit ERROR"
			$retCode = $critical
			$desc = $sum_cehck_desc
		}
	}
}

end {
switch ($retCode)
		{
			0 {$msgPrefix="OK"}
			1 {$msgPrefix="Warning"}
			2 {$msgPrefix="Critical"}
			3 {$msgPrefix="Unknown"}
				
		}	
	write-host $msgPrefix":" $desc $perfData
	exit $retCode
}