<#
  .SYNOPSIS
   script for nagios to check taht share drive exists, and accessibale.	
  .DESCRIPTION
   Auther Yossi Bitton yossi@edp.co.il
   Date: Jan 201   
  .EXAMPLE
	.\check_share_drive.ps1
   version 1.0.1
	
   for Nagios NRPE edit NSC.ini or nsclient.ini and add the following line under section:
	[Wrapped Scripts] 
	 check_mssql=check_share_drive.ps1 $ARG1$
	
	[Script Wrappings]
	ps1 = cmd /c echo scripts\%SCRIPT% %ARGS%; exit($lastexitcode) | powershell.exe -ExecutionPolicy Bypass -command -
	
#>

[CmdletBinding()]
Param(
	[parameter(Mandatory=$true,Position=1)] 
	[String[]]$uncPath ,
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
	
	if ($uncPath -ne $Null) {
		$testPath = Test-Path -Path $uncPath
		if ($testPath -eq $true) {
			$fileName = (get-date).ticks
			$filePath = "$uncPath\$fileName.test"
			try {
				$createFileStatus = New-Item -Type file $filePath
				if ($createFileStatus -ne $null) {
					$delFileStatus = Remove-Item -Path $filePath
					$desc = "Shared drive $uncPath is accessible and writable"
					$retCode = $ok
				}else{
					$desc = "Cannot Create file in share drive $uncPath"
					$retCode=$critical
				}
			}catch [UnauthorizedAccessException] {
				$desc = $_.Exception.Message
				$retCode = $critical
			}
		}else{
			$desc = "Cannot Access to share drive  $uncPath"
			$retCode=$critical
		}
		
	}else{
		$desc = "Missing UNC path for share to test"
		$retCode=$unknown
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
	write-host $msgPrefix":" $desc
	exit $retCode
}