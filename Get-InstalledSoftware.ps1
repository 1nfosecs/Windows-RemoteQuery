<#
.SYNOPSIS
	Get-InstalledSoftware retrieves a list of installed software
.DESCRIPTION
	Get-InstalledSoftware opens up the specified (remote) registry and scours it for installed software. When found it returns a list of the software and it's version.
.PARAMETER ComputerName
	The computer from which you want to get a list of installed software. Defaults to the local host.
.EXAMPLE
	Get-InstalledSoftware DC1
	
	This will return a list of software from DC1. Like:
	Name			Version		Computer  UninstallCommand
	----			-------     --------  ----------------
	7-Zip 			9.20.00.0	DC1       MsiExec.exe /I{23170F69-40C1-2702-0920-000001000000}
	Google Chrome	65.119.95	DC1       MsiExec.exe /X{6B50D4E7-A873-3102-A1F9-CD5B17976208}
	Opera			12.16		DC1		  "C:\Program Files (x86)\Opera\Opera.exe" /uninstall
.EXAMPLE
	Import-Module ActiveDirectory
	Get-ADComputer -filter 'name -like "DC*"' | Get-InstalledSoftware
	
	This will get a list of installed software on every AD computer that matches the AD filter (So all computers with names starting with DC)
.INPUTS
	[string[]]Computername
.OUTPUTS
	PSObject with properties: Name,Version,Computer,UninstallCommand
.NOTES
	Author: ThePoShWolf
	
	To add registry directories, add to the lmKeys (LocalMachine)
.LINK
	[Microsoft.Win32.RegistryHive]
    [Microsoft.Win32.RegistryKey]
    https://github.com/theposhwolf/utilities
#>
Function Get-InstalledSoftware {
    Param(
        [Alias('Computer','ComputerName','HostName')]
        #[Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Mandatory=$false,Position=1)]
		[Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,Mandatory=$false)]
        [string[]]$Name = $env:COMPUTERNAME,
		#[string]$Name
		[Switch]$StartRemoteRegistry
    )
    Begin{
        $lmKeys = "Software\Microsoft\Windows\CurrentVersion\Uninstall","SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        $lmReg = [Microsoft.Win32.RegistryHive]::LocalMachine
        $cuKeys = "Software\Microsoft\Windows\CurrentVersion\Uninstall"
        $cuReg = [Microsoft.Win32.RegistryHive]::CurrentUser
    }
    Process{
    try{    if (!(Test-Connection -ComputerName $Name -count 1 -quiet)) {
            
				Write-Error -Message "Unable to contact $Name. Please verify its network connectivity and try again." -Category ObjectNotFound -TargetObject $Name
				Write-Host "UNABLE TO CONNECT TO" $Name `n
				Continue
				
				
		
			}	
		
        # CONTINUE TESTING REMOTE REGISTRY LOGIC 9-2-20
		# If the remote registry service has STARTUP TYPE of "Disabled", this script won't start it 
        # If the remote registry service is stopped before this script runs it will be stopped again afterwards.
     
       
        $shouldStop = $false
        $service = Get-Service RemoteRegistry -Computer $Name
	
		Write-Host "REMOTE REGISTRY IS CURRENTLY" $service.Status "on" $Name "`n" 
		Write-Host "REMOTE REGISTRY STARTUP TYPE IS" $service.StartType on $Name `n		
		if ($service.Status -eq 'Stopped' -and $service.StartType -ne 'Disabled') {
                $shouldStop = $true
                $service | Start-Service
				Write-Host "REMOTE REGISTRY " $service.Status "on" $Name "`n"
        }
        
		
        $masterKeys = @()
        $remoteCURegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($cuReg,$Name)
        $remoteLMRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($lmReg,$Name)
        foreach ($key in $lmKeys) {
            $regKey = $remoteLMRegKey.OpenSubkey($key)
            foreach ($subName in $regKey.GetSubkeyNames()) {
                foreach($sub in $regKey.OpenSubkey($subName)) {
                    $masterKeys += (New-Object PSObject -Property @{
                        "ComputerName" = $Name -join ""
                        "Name" = $sub.GetValue("displayname")
                        "SystemComponent" = $sub.GetValue("systemcomponent")
                        "ParentKeyName" = $sub.GetValue("parentkeyname")
                        "Version" = $sub.GetValue("DisplayVersion")
                        "UninstallCommand" = $sub.GetValue("UninstallString")
                        "InstallDate" = $sub.GetValue("InstallDate")
                        "RegPath" = $sub.ToString()
                    })
                }
            }
        }
        foreach ($key in $cuKeys) {
            $regKey = $remoteCURegKey.OpenSubkey($key)
            if ($regKey -ne $null) {
                foreach ($subName in $regKey.getsubkeynames()) {
                    foreach ($sub in $regKey.opensubkey($subName)) {
                        $masterKeys += (New-Object PSObject -Property @{
                            "ComputerName" = $Name -join ""
                            "Name" = $sub.GetValue("displayname")
                            "SystemComponent" = $sub.GetValue("systemcomponent")
                            "ParentKeyName" = $sub.GetValue("parentkeyname")
                            "Version" = $sub.GetValue("DisplayVersion")
                            "UninstallCommand" = $sub.GetValue("UninstallString")
                            "InstallDate" = $sub.GetValue("InstallDate")
                            "RegPath" = $sub.ToString()
                        })
                    }
                }
            }
        }
        $woFilter = {$null -ne $_.name -AND $_.SystemComponent -ne "1" -AND $null -eq $_.ParentKeyName}
        $props = 'Name','Version','ComputerName','InstallDate','UninstallCommand','RegPath'
        $masterKeys = ($masterKeys | Where-Object $woFilter | Select-Object $props | Sort-Object Name)
        $masterKeys
		
		# Stop the remote registry service if required  
        if ($shouldStop) {
            #Start-Sleep 1
			$service | Stop-Service
			Write-Host "REMOTE REGISTRY IS CURRENTLY" $service.Status on $Name `n 
        }
    }
		catch
		{
			Write-Host $Name "HAD AN ERROR AND WASN'T PROCESSED" `n
		}
		
		finally
		{
			Write-Host "DONE PROCESSING" $Name `n
		}
	
}
    
	End{}
	
	
}

#### NOT CURRENTLY IN USE ####
Function Get-remoteProcesses {
        [CmdletBinding()]     
        param ( 
            [Parameter(Position=0, Mandatory = $true, HelpMessage="Provide server names", ValueFromPipeline = $true)] $Computername
            #[Parameter(Position=1, Mandatory = $false, HelpMessage="Provide username", ValueFromPipeline = $false)] $UserName = $env:USERNAME
        ) 
        $Array = @()
        Foreach ($Comp in $Computername) {
            $Comp = $Comp.Trim()
            Write-Verbose "Processing $Comp"
            Try{
                $Procs = $null
                $Procs = Invoke-Command $Comp -ErrorAction Stop -ScriptBlock{Get-Process -IncludeUserName} #| Where-Object {$_.username -match $Username}} -ArgumentList $Username
                If ($Procs) {
                    Foreach ($P in $Procs) {
                        $Object = $Mem = $CPU = $null
                        $Mem = [math]::Round($P.ws / 1mb,1)
                        $CPU = [math]::Round($P.CPU, 1)
                        $Object = New-Object PSObject -Property ([ordered]@{    
                                    "ServerName"             = $Comp
                                    "UserName"               = $P.username
                                    "ProcessName"            = $P.processname
                                    "CPU"                    = $CPU
                                    "Memory(MB)"             = $Mem
                        })
                        $Array += $Object 
                    }
                }
                Else {
                    Write-Verbose "No process found for $Username on $Comp"
                }
            }
           	
			Catch{
                Write-Verbose "Failed to query $Comp"
                Continue
            }
        
    If ($Array) {
        Return $Array
    }
}
}



$h = get-content $PSScriptRoot\computerlist.txt
		#Get-InstalledSoftware -ComputerName "win10" | Out-GridView
$results = foreach ($hname in $h)
{
		Get-InstalledSoftware -ComputerName $hname			
}

$results | select-object -Property ComputerName,Name,Version,InstallDate,RegPath | Export-csv SOFTWARE.csv -NoTypeInformation

#$results | format-table -Property ComputerName,DisplayName,Name,InstallDate,Username,Hive -AutoSize | out-file software.csv

<#GET REMOTE PROCESSES
$ProcessResults = foreach ($h_name in $h)
{
		Get-RemoteProcesses -ComputerName $h_name -Verbose		
}

#$results | format-table -Property ComputerName,DisplayName,Name,InstallDate,Username,Hive -AutoSize | out-file software.csv
$ProcessResults | select-object -Property ServerName,UserName,ProcessName | Export-csv PROCESSES.csv -NoTypeInformation #>


$installedPatches = foreach ($hostName in $h)
{
		try
		{
			Get-Hotfix -ComputerName $hostname 
		}
		catch
		{
			Write-Host $hostName "- NOT AVAILABLE.....COULD NOT RETRIEVE INSTALLED PATCHES"
			Continue
		}
		
}

$installedPatches |  Select-Object -Property "PSComputerName","Description","HotFixID","InstalledBy","InstalledOn" | Export-csv PATCHES.csv -NoTypeInformation
