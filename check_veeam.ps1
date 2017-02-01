# Adding required SnapIn

Add-PSSnapin VeeamPSSnapIn



# Global variables


# Veeam Backup & Replication job status check

$jobs = Get-VBRJob 
$period = 1
$state = 0
$success =0
$warning=0
$failed=0
$allJobs=""

foreach ($job in $jobs) 
{
    $status = $job.GetLastResult()
   
    $name = $job.Name
  
   
  #  Write-Host $name Status "-" 
    if ($status -eq "Failed")
    {
    	
	   $failed +=1
	   $allJobs = $allJobs + $name  + " Status -"  + $job.GetLastResult() + "`n" 
    }

     if ($status -eq "Warning")
    {
    	
	   $warning +=1
	    $allJobs = $allJobs + $name  + " Status -"  + $job.GetLastResult() + "`n" 
    }

     if ($status -eq "Success")
    {
    	
	   $success +=1
    }

   # Write-Host "Job" $name "Last Result:" $job.GetLastResult() 
   
}
$mydate = Get-Date -DisplayHint Date -Format dd-MM-yyyy
Write-Host "Veeam Backup and Replication Result for:" $mydate  "Success:"$success ",Warning:"$warning ",Failed:" $failed 
if ($warning -gt 0 -or $failed -gt 0) {
	write-host $allJobs }

else
{
	write-host "All Jobs Completed Successful, total jobs" $success  
	}

if ($failed -gt 0) {exit 2}
if ($warning -gt 0) {exit 1}
if ($success -gt 0) {exit 0}
 




	
# Veeam Backup & Replication job last run check

#$now = (Get-Date).AddDays(-$period)
#$now = $now.ToString("yyyy-MM-dd")
#$last = $job.GetScheduleOptions()
#$last = $last -replace '.*Latest run time: \[', ''
#$last = $last -replace '\], Next run time: .*', ''
#$last = $last.split(' ')[0]

#if((Get-Date $now) -gt (Get-Date $last))
#{
#	Write-Host "CRITICAL! Last run of job: $name more than $period days ago."
#	exit 2
#} 
#else
#{#
	#Write-Host "OK! Backup process of job $name completed successfully."
	#exit 0
#}
