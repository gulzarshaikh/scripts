# usage:
# ./archiveAndExtend.ps1 -vip mycluster `
#                        -username myuser `
#                        -domain mydomain.net `
#                        -policyNames 'my policy', 'another policy' `
#                        -jobNames 'my job 1', 'my job 2' `
#                        -newerThan 6 `
#                        -commit

# process commandline arguments
[CmdletBinding()]
param (
    # main params
    [Parameter(Mandatory = $True)][string]$vip, # cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username, # username (local or AD)
    [Parameter()][string]$domain = 'local', # local or AD domain
    [Parameter()][int32]$newerThan = 6, # don't process spanshots older than X days
    [Parameter()][switch]$commit, # if excluded script will run in test run mode and will not archive
    [Parameter()][array]$jobNames,
    [Parameter()][array]$policyNames
)

# start logging
$logfile = $(Join-Path -Path $PSScriptRoot -ChildPath log-extendRetention.txt)
"`nScript Run: $(Get-Date)" | Out-File -FilePath $logfile -Append

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain

# job selector
$jobs = api get protectionJobs
$policies = api get protectionPolicies

$global:processedExtensions = @()
$global:runCount = 0

function extendSnapshot($run, $keepDays){

    $editRun = $false

    $startTimeUsecs = $run.copyRun[0].runStartTimeUsecs
    $runDate = usecsToDate $startTimeUsecs

    $runParameters = @{
        "jobRuns"= @(
            @{
                "jobUid" = $run.jobUid;
                "runStartTimeUsecs" = $startTimeUsecs;
                "copyRunTargets" = @()
            }
        )
    }

    # calculate days to extend snapshot
    $currentExpireTimeUsecs = $run.copyRun[0].expiryTimeUsecs
    $newExpireTimeUsecs = $startTimeUsecs + ($keepDays * 86400000000)
    $newExpireDate = (usecsToDate $newExpireTimeUsecs).ToString('yyyy-MM-dd')
    $daysToExtend = [math]::Round(($newExpireTimeUsecs - $currentExpireTimeUsecs) / 86400000000)

    if("$($runDate.Year)-$($runDate.DayOfYear)-$($run.jobId)" -notin $global:processedExtensions){
        if($daysToExtend -ne 0){
            $runParameters.jobRuns[0].copyRunTargets += @{
                "daysToKeep" = [int] $daysToExtend;
                "type" = "kLocal"
            }
            if($commit){
                "  $runDate - extending to $newExpireDate" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                $editRun = $True
                $global:runCount += 1
            }else{
                "  $runDate - would extend to $newExpireDate" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Green
                $global:runCount += 1
            }
        }
        $global:processedExtensions += "$($runDate.Year)-$($runDate.DayOfYear)-$($run.jobId)"
    }
    
    # commit any changes
    if($editRun -eq $True){
        $null = api put protectionRuns $runParameters
    }
}

"`nDigging through job runs...`n"

foreach($job in $jobs | Sort-Object -Property name){
    $policy = $policies | Where-Object id -eq $job.policyId
    $policyDaysToKeep = $policy.daysToKeep
    if(!$policyNames -or $policy.name -in $policyNames){
        if(!$jobNames -or $job.name -in $jobNames){
            "$($job.name)" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor White
            $runs = api get "protectionRuns?jobId=$($job.id)&runTypes=kRegular&runTypes=kFull&excludeTasks=true&excludeNonRestoreableRuns=true&startTimeUsecs=$(timeAgo $newerThan days)" | `
                Where-Object { $_.backupRun.snapshotsDeleted -eq $false } | `
                Sort-Object -Property @{Expression = { $_.copyRun[0].runStartTimeUsecs }; Ascending = $True }
        
            foreach($run in $runs){
                extendSnapshot $run $policyDaysToKeep
            }
        }
    }
}

if($global:runCount -eq 0){
    "`nNo runs to extend`n" | Tee-Object -FilePath $logfile -Append | write-host -ForegroundColor Cyan
}
