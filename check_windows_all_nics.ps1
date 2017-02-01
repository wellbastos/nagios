<# NAME: check_windows_network_cards.ps1
   COMMENT: The script will get the status of all pysical network cards, and return	ok when all 
   network cards ard connected (status = 2) and critical when when status not equal to 2.
   AUTHOR: Yossi Bitton - yossi@edp.co.il
   DATE: 31-8-2015
   
   instraction for nsclient:
   1: copy the script to c:\program files\nsclient++\scripts folder
   2: edit the NSC.ini file and add the following line.
	check_nic = check_windows_network_cards.ps1
   3: restart the nsclient service
   4: in NAGIOS XI add SERVICE name "Network Interface" command check nrpe $ARG1$ = check_nic
   
 #>
	
 
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
			$query = "SELECT * FROM Win32_NetworkAdapter WHERE Manufacturer != 'Microsoft' AND NOT PNPDeviceID LIKE 'ROOT\\%'"
			$nicList = Get-WmiObject -Query $query 
	}Catch{
			$msg = "an error has occurred when trying to get Network adapter list "
			return $false ,$msg
	}
	
	if ($nicList -ne $null) {
		if ($nicList -is [system.array]) {
			$nicCount = $nicList.Count
			foreach ($nic in $nicList) {
				if($nic.NetConnectionStatus -ne 2) {
					$desc = $desc + $nic.NetConnectionID + "=" +  (Get-StatusFromValue($nic.NetConnectionStatus)) + ", "
					$notConnected +=1
				}
			}		
		}else{  #nicList isnot array (only 1 nic present)
			$nicCount = 1
			if($nicList.NetConnectionStatus -ne 2) {
				$desc = $nic.NetConnectionID + " " +  (Get-StatusFromValue($nicList.NetConnectionStatus))
				$notConnected =1
			}
		}
	}else{ # $nicList -eq $null
		$msg = "an error has occurred when trying to get Network adapter list "
		return $false ,$msg
	}

	if ($notConnected -gt 0) {
		$msg = "CRITICAL: $desc Number of nic error: ($notConnected/$nicCount)"  
		return  $false , $msg 
	}else{
		if($nicCount -gt 1){
			$msg =  "OK: $nicCount network interfaces are connected ($nicCount/$nicCount)"
		}else{
			$msg =  "OK: $nicCount network interface is connected ($nicCount/$nicCount)"
		}
		return $true , $msg
	}
}


function Main()
{
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