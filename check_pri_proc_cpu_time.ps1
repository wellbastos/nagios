$ErrorActionPreference= 'silentlycontinue'
$CPU_MAX_TIME = 20
$global:exitStatus = 3
$global:nagiosMsg = ""
$global:totalHangProcess = 0
$global:totalFoundProcess = 0
$userList = "admin", "administrator" , "dani" , "edpadm" , "gennady" , "sqladmin"
$processList = "winactiv" , "winform" ,"SQLI" 


function check_cpu_time($procStr)
{
	$procCountList =  ps $procStr | select name, StartTime ,id 
	#write-host $procCountList
	foreach ($proc in $procCountList) 
	{
		$date = Get-date
		$startTime = $proc.StartTime
		$procTime = ($date - $startTime).TotalMinutes
				# Reset $global:exitStatus from Unknown to OK.
				if ($global:exitStatus -eq 3) {$global:exitStatus = 0}
				$global:totalFoundProcess +=1
				if($procTime -gt $CPU_MAX_TIME) 
				{
					$procDetails =  gwmi Win32_Process -Filter ("Handle={0}" -f $proc.id ) |
				   % { Add-Member `
					   -InputObject $_ `
					   -MemberType NoteProperty `
					   -Name Owner `
					   -Value ($_.GetOwner().User) `
					   -PassThru } |
					select Name, CommandLine, ProcessId, Owner
					if($userList.Contains($procDetails.Owner)) 
					{
						$global:totalHangProcess +=1
						$username = $procDetails.Owner
						$commandLine = $procDetails.CommandLine
						$global:exitStatus = 2
						$procTime = [int]$procTime
						$global:nagiosMsg += "Proccess=$procStr StatTime=$startTime , " 
						
					}
				}
			#}
	}
}

foreach ($p in $processList) {
	check_cpu_time($p)
	}
	
if ($global:totalFoundProcess -eq 0)
{
	write-host "No process with name $processList found"
	exit 0 
}
	
if ($global:exitStatus -eq 2) 
{
	write-host "Total stuck processes is: $global:totalHangProcess `r`n $global:nagiosMsg"
	exit 2 
}
if ($global:exitStatus -eq 0 )
 {
	write-host "Processes: $processList are Running OK, Total process found is: $global:totalFoundProcess"
	exit 0
}

	

	