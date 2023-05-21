Function Get-LocalAdmins {
<#
.SYNOPSIS
Gets the members of the local administrators of the computer 
and outputs the result to a CSV file.
.PARAMETER Computers
Specifies the Computer names of devices to query
.INPUTS
System.String. Get-LocalAdmins can accept a string value to
determine the Computers parameter.
.EXAMPLE
Get-LocalAdmins -Computers CL1,CL2
.EXAMPLE
Get-LocalAdmins -Computers (Get-Content -Path "$env:HOMEPATH\Desktop\computers.txt")
.EXAMPLE
Get-LocalAdmins -Computers DC,SVR8 | Format-Table -AutoSize -Wrap
.EXAMPLE
Get-LocalAdmins -Computers DC,SVR8 | Export-Csv -Path "$env:HOMEPATH\Desktop\LocalAdmin.csv" -NoTypeInformation
.LINK
Source script: https://gallery.technet.microsoft.com/223cd1cd-2804-408b-9677-5d62c2964883
#>

    Param(
        [Parameter(Mandatory)]
        [string[]]$Computers
        )
    # testing the connection to each computer via ping before
    # executing the script
    foreach ($computer in $Computers) {
        if (Test-Connection -ComputerName $computer -Quiet -count 1) {
            $livePCs += $computer
        } else {
            Write-Verbose -Message ('{0} is unreachable' -f $computer) -Verbose
        }
    }

    $list = new-object -TypeName System.Collections.ArrayList
    foreach ($computer in $livePCs) {
        $admins = Get-WmiObject -Class win32_groupuser -ComputerName $computer | Where-Object {$_.groupcomponent -like '*"Administrators"'}
		$LocalUsers += Invoke-Command $computer -ErrorAction SilentlyContinue -ScriptBlock{Get-LocalUser | Select-Object PSComputerName,Name,FullName,Enabled,LastLogon,PasswordLastSet,PasswordRequired,PasswordExpires,Description,SID} #| Sort-Object PSComputerName,Name,FullName,Enabled,LastLogon,PasswordLastSet,PasswordRequired,PasswordExpires,Description,SID}
		#$userInfo = Get-WmiObject -Class Win32_UserAccount -Namespace "root\cimv2" ` -Filter "LocalAccount='$True'" -ComputerName $computer -Credential $Credential -ErrorAction Stop 		
        
		$obj = New-Object -TypeName PSObject -Property @{
            ComputerName = $computer
            LocalAdmins = $null
        }
        foreach ($admin in $admins) {
            $null = $admin.partcomponent -match '.+Domain\=(.+)\,Name\=(.+)$' 
            $null = $matches[1].trim('"') + '\' + $matches[2].trim('"') + "`n"
            $obj.Localadmins += $matches[1].trim('"') + '\' + $matches[2].trim('"') + "`n"
			#write-host $obj.Localadmins
        }
        $null = $list.add($obj)
    }
	
    $LocalUsers | Select-Object "PSComputerName","Name","FullName","Enabled","LastLogon","PasswordLastSet","PasswordRequired","PasswordExpires","Description","SID" | Export-csv -path $PSScriptRoot\LOCAL-ACCOUNTS\$computer`-ALL_LOCAL_USERS.csv -NoTypeInformation
	$list

}

Function Get-RemoteLocalUsers-LEGACY
{
	Param(
        [Parameter(Mandatory)]
        [string[]]$Computers
        )


	foreach ($computer in $Computers) {
        if (Test-Connection -ComputerName $computer -Quiet -count 1) {
            $livePCs += $computer
        } else {
            Write-Verbose -Message ('{0} is unreachable' -f $computer) -Verbose
        }
    }
	foreach ($computer in $livePCs) {

		$LocalUsersResult += Get-WmiObject -Class Win32_UserAccount -Namespace "root\cimv2" ` -Filter "LocalAccount='$True'" -ComputerName $computer | select-object PSComputerName,Name,FullName,Disabled,PasswordExpires,PasswordRequired,Description


	}
		#$ServiceResult
		$LocalUsersResult
}

Function Get-RemoteServices
{
Param(
        [Parameter(Mandatory)]
        [string[]]$Computers
        )


foreach ($computer in $Computers) {
        if (Test-Connection -ComputerName $computer -Quiet -count 1) {
            $livePCs += $computer
        } else {
            Write-Verbose -Message ('{0} is unreachable' -f $computer) -Verbose
        }
    }
foreach ($computer in $livePCs) {

		$ServiceResult += Get-service -ComputerName $computer | Select-object "MachineName","Status","Name","DisplayName"
		#$ProcessResult += Get-WmiObject Win32_Process -ComputerName $computer | select-object "PSComputerName","ProcessName","Path","CommandLine"


	}
		$ServiceResult
		#$ProcessResult
}

Function Get-RemoteProcesses
{
Param(
        [Parameter(Mandatory)]
        [string[]]$Computers
        )


foreach ($computer in $Computers) {
        if (Test-Connection -ComputerName $computer -Quiet -count 1) {
            $livePCs += $computer
        } else {
            Write-Verbose -Message ('{0} is unreachable' -f $computer) -Verbose
        }
    }
foreach ($computer in $livePCs) {

		#$ServiceResult += Get-service -ComputerName $computer | Select-object "MachineName","Status","Name","DisplayName"
		$ProcessResult += Get-WmiObject Win32_Process -ComputerName $computer | select-object "PSComputerName","Name","ProcessName","Path","CommandLine"


	}
		#$ServiceResult
		$ProcessResult
}

Function Get-RemoteTimeServer {
	Param(
        [Parameter(Mandatory)]
        [string[]]$Computers
        )


	foreach ($computer in $Computers) {
        if (Test-Connection -ComputerName $computer -Quiet -count 1) {
            $livePCs += $computer
        } else {
            Write-Verbose -Message ('{0} is unreachable' -f $computer) -Verbose
        }
    }
	foreach ($computer in $livePCs) {

			$ntps += w32tm /query /computer:$Computer /source
			$results += (new-object psobject -property @{

            Name = $computer
			NTPSource = $ntps

	})
		
		$results
		#$ProcessResult
	}
}


##CALLING GET-LOCALADMINS##
write-host "Getting Local Administrator Information..."
New-Item -Path "$PSScriptRoot\" -Name "LOCAL-ACCOUNTS" -ItemType "directory" -ErrorAction SilentlyContinue | Out-Null
$h = get-content $PSScriptRoot\computerlist.txt
$AdminResults = foreach ($hname in $h)
{
	Get-LocalAdmins -Computers $hname
}
$AdminResults | Sort-Object ComputerName | Export-csv $PSScriptRoot\LOCAL-ACCOUNTS\ALL_LOCAL_ADMINS.csv -NoTypeInformation

##CALLING GET-RemoteLocalUsers-LEGACY##
$LocalUsers = foreach ($hname in $h)
{
	Get-RemoteLocalUsers-LEGACY -Computers $hname
}
$LocalUsers | Select-Object "PSComputerName","Name","FullName","Disabled","PasswordExpires","PasswordRequired","Description" | Export-csv $PSScriptRoot\LOCAL-ACCOUNTS\ALL_LOCAL_USERS.csv -NoTypeInformation

##CALLING GET-REMOTESERVICES##
write-host "Getting Remote Services Information..."
$RemoteServices = foreach($hname in $h)
{
	 Get-RemoteServices -Computers $hname | Select-object "MachineName","Status","Name","DisplayName"
}
$RemoteServices | export-csv SERVICES.csv -NoTypeInformation

##CALLING GET-REMOTEPROCESSES##
write-host "Getting Remote Process Information..."
$RemoteProcesses = foreach($hname in $h)
{
	 Get-RemoteProcesses -Computers $hname | Select-object "PSComputerName","Name","ProcessName","Path","CommandLine"
}
$RemoteProcesses | export-csv PROCESSES.csv -NoTypeInformation

##CALLING GET-REMOTETIMESERVER##
write-host "Getting NTP Server Information"
$RemoteTimeServer = foreach($hname in $h)
{
	 Get-RemoteTimeServer -Computers $hname | Select-object "Name","NTPSource"
}
$RemoteTimeServer | export-csv TIMESERVERS.csv -NoTypeInformation