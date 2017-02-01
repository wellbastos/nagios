<# NAME: check_windows_network_cards.ps1
   COMMENT: The script will get the status of all pysical network cards, and return	ok when all 
   network cards ard connected (status = 2) and critical when when status not equal to 2.
   AUTHOR: Yossi Bitton - yossi@edp.co.il
   DATE: 31-8-2015
   Update: 3-2-2016 Change to Individual Nic
   
   instraction for nsclient:
   1: copy the script to c:\program files\nsclient++\scripts folder
   2: edit the NSC.ini file and add the following line.
	check_nic = check_windows_network_cards.ps1
   3: restart the nsclient service
   4: in NAGIOS XI add SERVICE name "Network Interface" command check nrpe $ARG1$ = check_nic
   
 #>
	
[CmdletBinding()]
Param(
	[parameter(Mandatory=$false,Position=1)]
	[Alias("Nic")]
	[string]$NicName
)
	
$OK = 0
$WARNING = 1
$CRITICAL = 2
$UNKNOWN = 3
$desc = ""

#convert status number to text
function Get-StatusFromValue

{
Param($statusNumber)
switch($statusNumber)
  {
   0 { "Disabled" }
   1 { "Connecting" }
   2 { "Connected" }
   3 { "Disconnecting" }
   4 { "Hardware not present" }
   5 { "Hardware disabled" }
   6 { "Hardware malfunction" }
   7 { "Media disconnected" }
   8 { "Authenticating" }
   9 { "Authentication succeeded" }
   10 { "Authentication failed" }
   11 { "Invalid Address" }
   12 { "Credentials Required" }
   Default { "Not connected" }
  }
} #end Get-StatusFromValue function

#check Network Adapter connection status, check only physical network adapter
function CheckNetworkCards {
$notConnected = 0
	try{
			#$query = "SELECT * FROM Win32_NetworkAdapter WHERE Manufacturer != 'Microsoft' AND NOT PNPDeviceID LIKE 'ROOT\\%'"
			$query = "SELECT * FROM Win32_NetworkAdapter"
			$nicResult = Get-WmiObject -Query $query 
	}Catch{
			$msg = "an error has occurred when trying to get Network adapter list "
			return $false ,$msg
	}
	
	$nicList = [array]$nicResult
	if ($nicList -ne $null) {
			foreach ($nic in $nicList) {
				if ($nic.NetConnectionID -eq "$NicName"){	
					$nicFound = $true
					$desc = "Nic Name - " + $nic.NetConnectionID + " - Status: " +  (Get-StatusFromValue($nic.NetConnectionStatus)) 
					if ($nic.NetConnectionStatus -ne 0) {
						if($nic.NetConnectionStatus -ne 2) {
							$notConnected = $true
						}
					}
				}
			}
	if ($nicFound -eq $false) {
		$desc = "$NicName not found in the system"
		 Write-Host "UNKNOWN:" $desc
		 exit $UNKNOWN
	}
		
	}else{ # $nicList -eq $null
		$msg = "an error has occurred when trying to get Network adapter list "
		return $false ,$msg
	}

	if ($notConnected -eq $true) {
		$msg = "CRITICAL: $desc" 
		return  $false , $msg 
	}else{
		$msg = "OK: $desc" 
		return $true , $msg
	}
}


function Main()
{
	$nicFound  = $false
	if (! $NicName) {
		 $desc = "The Argument NicName is missing"
		 Write-Host "UNKNOWN" $desc
		 exit $UNKNOWN
	}
	$status,$desc = CheckNetworkCards
	if($status -eq $true)
		{
			Write-Host $desc
			exit $OK
		}else{
			Write-Host $desc
			exit $CRITICAL
		}
Write-Host "an error has occurred when trying to check the network status"
exit $UNKNOWN
}

# We Start here, and we Call to main function 
Main