Configuration PrepareWitness
{

	param 
    ( 
		[Parameter(Mandatory)]
        [String]$ComputerName,

        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=60
    )

Import-DscResource -ModuleName xSmbShare, xDisk, cDisk, xComputerManagement, xPendingReboot, xActiveDirectory, PSDesiredStateConfiguration

	[System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

Node localhost
  {
	LocalConfigurationManager            
    {            
      ActionAfterReboot = 'ContinueConfiguration'            
      ConfigurationMode = 'ApplyOnly'            
      RebootNodeIfNeeded = $true            
    }

	xWaitforDisk Disk2
    {
         DiskNumber = 2
         RetryIntervalSec =$RetryIntervalSec
         RetryCount = $RetryCount
    }

    cDiskNoRestart DataDisk
    {
        DiskNumber = 2
        DriveLetter = "F"
    }

    WindowsFeature ADPS
    {
        Name = "RSAT-AD-PowerShell"
        Ensure = "Present"
    }

	xComputer JoinDomain
    {
	  Name = $ComputerName
      DomainName = $DomainName
      Credential = $DomainCreds # Credential to join to domain
    }

	File FSWFolder
    {
        DestinationPath = "F:\$($SharePath.ToUpperInvariant())"
        Type = "Directory"
        Ensure = "Present"
        DependsOn = "[xComputer]JoinDomain"
    }

    xSmbShare FSWShare
    {
        Name = $SharePath.ToUpperInvariant()
        Path = "F:\$($SharePath.ToUpperInvariant())"
        FullAccess = "BUILTIN\Administrators"
        Ensure = "Present"
        DependsOn = "[File]FSWFolder"
    }

	xPendingReboot Reboot
    { 
      Name = "RebootServer"
      DependsOn = "[xComputer]JoinDomain"
    }
  }
}