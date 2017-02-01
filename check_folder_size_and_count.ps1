 <#
  .SYNOPSIS
   script for nagios to check size or count or accessible for folders	
  .DESCRIPTION
   Auther Yossi Bitton yossi@edp.co.il
   Date: November 2015   
  .EXAMPLE
	.\check_folder_size_and_count.ps1 -checkType size -path 'c:/test' -warn 100 -crit 200
  .EXAMPLE
	.\check_folder_size_and_count.ps1 -checkType size -path 'c:/test' -warn 2 -crit 3 -unit GB
  .EXAMPLE
	the script can determinate the position of the arguments so you can type:
	.\check_folder_size_and_count.ps1 size 'c:/test' 100 200
	.\check_folder_size_and_count.ps1 size 'c:/test' 100 200 GB
  .EXAMPLE
	Test the count of files under folder c:/test and sub-folder, bellow 100=OK 100+=warning 200+=critical
	.\check_folder_size_and_count.ps1 count 'c:/test' 100 200
  .EXAMPLE
	Test if folder c:\test has accessible for read and write
	.\check_folder_size_and_count.ps1 access 'c:/test' 
  .PARAMETER checkType
 	Access|Size|Count
	Access: if folder exist and accessible for writing
	Size: Get the size of the folder
	Count: Count the files under folder and sub-folder
  .PARAMETER Path
   The Path of folder 
  .PARAMETER warn
	The Warning level , default is MB, (unless you set -unit GB) 
  .PARAMETER crit
	The Critical level, default is MB, (unless you set -unit GB)
  .PARAMETER unit 
	<size unit MB (default) or GB>
  #>

[CmdletBinding(
	)]
Param(
	[parameter(Mandatory=$true ,Position=1)]  [string]$checkType, # Access , Size , Count
	[parameter(Mandatory=$true ,Position=2)]  [string]$path,	# path of directoy to check 
	[parameter(Mandatory=$false ,Position=3)] [string]$warn,	# warning if size by GB example: 10GB if count by number example: 100 (files)
	[parameter(Mandatory=$false ,Position=4)] [string]$crit,# critical if size by GB example: 20GB if count by number example: 200 (files)
	[parameter(Mandatory=$false ,Position=5)] [string]$unit="MB"	# MB or GB default is MB
	
)

begin {

	
	function Validate-Parameters()	{
		if ($checkType -ne "Access" -and $checkType -ne "Size" -and $checkType -ne "Count"){
			 $desc = "$checkType ,is not valid, valid checkType is:  Access|Size|Count `n" 
			 return $false,$desc 
		}
		if(!($path)){
			$desc = "FolderPath argument missing... `n"
			return $false,$desc 
		}
		if ($checkType -eq "Size" -or $checkType -eq "Count"){
			if ( ( !(Is-Numeric($crit))) -or ( !(Is-Numeric($warn))) -or ($crit -eq $null) -or ($warn -eq $null)){
				$desc="Invalid critical or warning value."
				return $false,$desc 
			}
			if( !(Test-path -path $path -PathType Container)){
				$desc="The folder $path does not exist"
				return $false,$desc
			}
			if ([int]$warn -gt [int]$crit) {
				$desc="Warning level cannot be grater that Critical level."
				return $false,$desc
			}
			
		}
		if($checkType -eq "Size"  -and $unit -ne "" -and $unit -ne $null){ 
			if($unit -ne "GB" -and $unit -ne "MB"){
				$desc="Unit value must be either GB or MB"
				return $false,$desc
			}
		}
	$desc="All parameters are OK."	
	return $true,$desc
	}
	
	
	function Is-Folder-Accessibility () {
		if(Test-path -path $path -PathType Container){
			$fullFilePath=$path + "\" + $testFile
			$date=Get-Date
			# Try to create test file in folder
			$newFileResult= New-Item -Path $fullFilePath -Type File -Value "Created by Nagios, for Test $date" -Force
			if($newFileResult){
			# Try to delete the file from folder	
				Remove-Item -Path $fullFilePath -ErrorAction SilentlyContinue
				if((Test-path $fullFilePath) -eq $False){
					$desc ="The folder $path exists and accessible"
					return $ok,$desc
				}else{	
					$desc="The file $testFile was created bat cannot be deleted..."
					return $warning,$desc
				}
				
			}else{
				$desc="Cannot create test file $testFile in folder $path"
				return $critical,$desc
			}	
		}else{
			$desc="The folder $path does not exist"
			return $critical,$desc
		}
	}	
	
	
	function Get-Folder-Size {
		$sizeInBytes=Get-ChildItem $path -Force -Recurse -ErrorAction SilentlyContinue | Measure-Object -property length -sum 
		$sizeForOutPut=$sizeInBytes.sum / "1$unit"
		$sizeForOutPut = $sizeForOutPut | % {$_.ToString("#.##")}
		$sizeForOutPut += " $unit"
		if ($sizeForOutPut -lt 1){
			 $sizeForOutPut="{0:N0}" -f ($sizeInBytes.sum / 1MB) + " MB"
		 }
		$sizeInMB=($sizeInBytes.sum / 1MB)
		$perfData=Get-Perf-Data("{0:0}" -f ($sizeInMB))
		$desc="The size of folder $path is $sizeForOutPut"
		if ($unit -eq "GB") {
			$crit = [int]$crit * 1024
			$warn = [int]$warn * 1024
		}
		if($sizeInMB -gt [int]$crit) {
			return $critical,$desc,$perfData
		}
		if ($sizeInMB -gt [int]$warn) {
			return $warning,$desc,$perfData
		}else{
			return $ok,$desc,$perfData
		}
			
	$desc="an error has occurred when trying to get the folder $path size"
	return $unknown,$desc,""
	
	}
	
	function Is-Numeric ($value) {
		return $value -match "^[\d\.]+$"
}
	
	function Get-Files-Count {
		$totalFiles=(Get-ChildItem -Path $path -Force -Recurse -ErrorAction SilentlyContinue | where { ! $_.PSIsContainer }).count
		if ($totalFiles -ne $null){
			$perfData=Get-Perf-Data($totalFiles)
			$desc="The folder $path contain $totalFiles files"
			if($totalFiles -gt $crit) {
				return $critical,$desc,$perfData
			}
			if ($totalFiles -gt $warn) {
				return $warning,$desc,$perfData
			}else{
				return $ok,$desc,$perfData
			}
		}
	$desc="an error has occurred when trying to get the folder $path size"
	return $unknown,$desc,""
	}
	
	function Get-Perf-Data {
		Param($result)
		#$resultOutPut=$result
		$resultOutPut = $result -replace " ", ""
		#$result = $result -replace "GB|MB", ""
		$perfData = $perfData -replace " ", ""
		
		if ($unit -eq "GB") {
			$crit = "{0:0}" -f ([int]$crit * 1024)
			$warn = "{0:0}" -f ([int]$warn * 1024)
		}
		if($checkType -eq "Size"){
			$perfData = "|'$checkType in MB'=" + $resultOutPut + "MB" + ";$warn;$crit;$result"
		}else{
			$perfData = "|'$checkType'=" + $resultOutPut + ";$warn;$crit;$result"
		}	
		return $perfData
	}
}
 


process {
	$ok=0
	$warning=1
	$critical=2
	$unknown=3
	$testFile="NagiosTest.txt"
	$retCode,$desc = Validate-Parameters
	if ($retCode){	
			 switch ($checkType)
			{
				"Access" { $retCode,$desc,$perfData=Is-Folder-Accessibility}
				"Size"  { $retCode,$desc,$perfData=Get-Folder-Size}
				"Count" { $retCode,$desc,$perfData=Get-Files-Count}
			}  
	}else{
		$scriptName=$MyInvocation.MyCommand.Name
		$desc+=" Type Get-Help .\$scriptName  -example to get help."
		$retCode=$unknown
	}
}

end{
	switch ($retCode)
		{
			"0" {$msgPrefix="OK"}
			"1" {$msgPrefix="Warning"}
			"2" {$msgPrefix="Critical"}
			"3" {$msgPrefix="Unknown"}
				
		}
	write-host $msgPrefix":" $desc" "$perfData 
	exit $retCode
}
 

 
