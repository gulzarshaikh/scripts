# Protect Physical Linux Hosts using PowerShell

Warning: this code is provided on a best effort basis and is not in any way officially supported or sanctioned by Cohesity. The code is intentionally kept simple to retain value as example code. The code in this repository is provided as-is and the author accepts no liability for damages resulting from its use.

This PowerShell script adds physical Linux servers to a file-based protection job.

**Warning:** The script will overwrite existing exclusions of a server if the server is included in the list of servers to process.

## Download the script

Run these commands from PowerShell to download the script(s) into your current directory

```powershell
# Download Commands
$scriptName = 'protectLinuxV2'
$repoURL = 'https://raw.githubusercontent.com/bseltz-cohesity/scripts/master/powershell'
(Invoke-WebRequest -Uri "$repoUrl/$scriptName/$scriptName.ps1").content | Out-File "$scriptName.ps1"; (Get-Content "$scriptName.ps1") | Set-Content "$scriptName.ps1"
(Invoke-WebRequest -Uri "$repoUrl/cohesity-api/cohesity-api.ps1").content | Out-File cohesity-api.ps1; (Get-Content cohesity-api.ps1) | Set-Content cohesity-api.ps1
# End Download Commands
```

## Components

* protectLinuxV2.ps1: the main PowerShell script
* cohesity-api.ps1: the Cohesity REST API helper module

Place all files in a folder together. Optionally create a text file called servers.txt and populate with the servers that you want to protect, like so (you can also specify servers on the command line):

```text
server1.mydomain.net
server2.mydomain.net
```

Note that the servers in the text file must be registered in Cohesity, and should match the name format as shown in the Cohesity UI.

Next optionally create a text file called inclusions.txt and populate with the paths that you want to include in the backup like so (you can also specify inclusions on the command line):

```text
/home
/var
```

Next optionally create a text file called exclusions.txt and populate with the folder paths that you want excluded from every server in the job, like so (you can also specify exclusions on the command line):

```text
/home/cohesityagent
/var/log
*.dbf
```

Then, run the main script like so:

```powershell
./protectLinuxV2.ps1 -vip mycluster `
                     -username myusername `
                     -domain mydomain.net `
                     -jobName 'File-based Linux Job' `
                     -servers server1.mydomain.net, server2.mydomain.net `
                     -serverList .\serverlist.txt `
                     -inclusions /var, /home `
                     -inclusionList .\inclusions.txt `
                     -exclusions /var/log, /home/cohesityagent `
                     -exclusionList .\exclusions.txt `
                     -skipNestedMountPoints
```

```text
Connected!
Processing servers...
  server1.mydomain.net
  server2.mydomain.net
```

## Parameters

* -vip: name or IP of Cohesity cluster
* -username: name of user to connect to Cohesity
* -domain: your AD domain (defaults to local)
* -jobName: name of protection job
* -servers: one or more servers (comma separated) to add to the proctection job
* -serverList: file containing list of servers
* -inclusions: one or more inclusion paths (comma separated)
* -inclusionList: a text file list of paths to include
* -exclusions: one or more exclusion paths (comma separated)
* -exclusionList: a text file list of exclusion paths
* -skipNestedMountPoints: (6.3 and below) if omitted, nested mount points will not be skipped
* -skipNestedMountPointTypes: (6.4 and above) comma separated list of mount point types to skip (e.g. nfs, xfs)
* -replaceRules: if omitted, inclusions/exclusions are appended to existing server rules (if any)
* -allServers: inclusions/exclusions are applied to all servers in the job
