Configuration JoinDomain
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

Import-DscResource -ModuleName xComputerManagement, xPendingReboot, PSDesiredStateConfiguration

	[System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

Node localhost
  {
	LocalConfigurationManager            
    {            
      ActionAfterReboot = 'ContinueConfiguration'            
      ConfigurationMode = 'ApplyOnly'            
      RebootNodeIfNeeded = $true            
    }

	xComputer JoinDomain
    {
	  Name = $ComputerName
      DomainName = $DomainName
      Credential = $DomainCreds # Credential to join to domain
    }

	xPendingReboot Reboot
    { 
      Name = "RebootServer"
      DependsOn = "[xComputer]JoinDomain"
    }
  }
}