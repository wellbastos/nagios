<#
  .SYNOPSIS
   script for nagios to check taht file is modify in last x hours.	
  .DESCRIPTION
   Auther Yossi Bitton yossi@edp.co.il
   Date: Jan 201   
  .EXAMPLE
	.\check_file_modify.ps1
   version 1.0.1
	
   for Nagios NRPE edit NSC.ini or nsclient.ini and add the following line under section:
	[Wrapped Scripts] 
	 check_file_modify=check_file_modify.ps1 $ARG1$
	
	[Script Wrappings]
	ps1 = cmd /c echo scripts\%SCRIPT% %ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command -
	
#>

[CmdletBinding()]
Param(
	[parameter(Mandatory=$true,Position=1)] 
	[String[]]$fileName ,
	[parameter(Mandatory=$true,Position=2)] 
	[int]$number ,
	[parameter(Mandatory=$false,Position=3)] 
	[ValidateSet("minute", "hour", "day")] 
	[String]$timeUnit ,
	[parameter(Mandatory=$false,Position=2)]
	[boolean]$DebugMode 
)
begin {

#Close End Section
}


	
process {
	$ok=0
	$warning=1
	$critical=2
	$unknown=3
	$retCode = $unknown
	
	if ($timeUnit -eq $Null) { 
		$timeUnit = "minute"
	}
	
	if ($fileName -ne $Null -And $number -ne $Null) {
		$testPath = Test-Path -Path $fileName
		if ($testPath -eq $true) {
			$LastWriteTime = (Get-ItemProperty -Path $fileName).LastWriteTime
			$date = Get-date
			$timeDiff = ($date - $LastWriteTime).TotalSeconds
			 switch($timeUnit) {
				"minute" {$diff = ([int]($timeDiff) / 60 ) }
				"hour" {$diff = ([int]($timeDiff) / 60 / 60 ) }
				"day" {$diff = ([int]($timeDiff) / 60 / 60  / 24 ) }
			 }
			 if ($diff -gt $number) {
				$desc = "File $fileName is older, last modify: $LastWriteTime"
				$retCode = $critical
			}else{
				$desc = "File $fileName is up to date, last modify: $LastWriteTime"
				$retCode = $ok
			}
			
		}else{
			$desc = "File $fileName does not exists"
			$retCode=$critical
		}
	}else{
		$desc = "Missing parameters, file name or number of minute"
		
	}
}
end 
{
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