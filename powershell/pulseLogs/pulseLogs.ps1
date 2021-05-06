# usage: ./getPureSnapshotNames.ps1 -vip mycluster -username myuser -domain mydomain.net -jobName 'My Job'

# process commandline arguments
[CmdletBinding()]
param (
    [Parameter(Mandatory = $True)][string]$vip,  # the cluster to connect to (DNS name or IP)
    [Parameter(Mandatory = $True)][string]$username,  # username (local or AD)
    [Parameter()][string]$domain = 'local',  # local or AD domain
    [Parameter()][string]$outPath = './pulseLogs'
)

$null = New-Item -ItemType Directory -Path $outPath -Force

# source the cohesity-api helper code
. $(Join-Path -Path $PSScriptRoot -ChildPath cohesity-api.ps1)

# authenticate
apiauth -vip $vip -username $username -domain $domain -quiet

$jobs = api get protectionJobs

foreach($job in $jobs | Where-Object {$_.isActive -ne $False} | Sort-Object -Property name){
    "$($job.name)"
    $runs = api get "protectionRuns?jobId=$($job.id)" | Where-Object {$_.backupRun.snapshotsDeleted -eq $false}
    foreach($run in $runs){
        $runId = $run.backupRun.jobRunId
        $runStatus = $run.backupRun.status
        $runDate = usecsToDate $run.backupRun.stats.startTimeUsecs
        $outFile = Join-Path -Path $outPath -ChildPath "$($job.name)-$($runDate.ToString('yyyy-MM-dd-hh-mm-ss'))-$($runStatus)-logs.txt"
        "    $runDate -> $outFile"
        if(! (Test-Path -Path $outFile)){
            foreach($source in $run.backupRun.sourceBackupStatus){
                $sourceName = $source.source.name
                $sourceStatus = $source.status
                "`n$sourceName ($sourceStatus)`n" | Out-File -FilePath $outFile -Append
                $progressPath, $taskPath = $source.progressMonitorTaskPath.split('/')
                $taskMon = api get "/progressMonitors?taskPathVec=$progressPath&includeFinishedTasks=true&excludeSubTasks=false"
                $thisTask = $taskMon.resultGroupVec[0].taskVec | Where-Object {$_.taskPath -eq $progressPath}
                $thisSubTask = $thisTask.subTaskVec | Where-Object {$_.taskPath -eq $taskPath}
                $events = $thisSubTask.progress.eventVec
                foreach($event in $events){
                    "$($event.eventMsg)" | Out-File -FilePath $outFile -Append
                }
            }
        }
    }
}
