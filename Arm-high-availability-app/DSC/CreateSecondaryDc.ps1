Configuration CreateSecondaryDc 
{ 
   param 
    ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=60
    )

    Import-DscResource -ModuleName xActiveDirectory, xPendingReboot
    [System.Management.Automation.PSCredential]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {
       LocalConfigurationManager            
       {            
          ActionAfterReboot = 'ContinueConfiguration'            
          ConfigurationMode = 'ApplyOnly'            
          RebootNodeIfNeeded = $true            
       }

       WindowsFeature RSAT 
       {
          Ensure = "Present"
          Name = "RSAT"
       }

       WindowsFeature ADDSInstall 
       { 
          Ensure = "Present" 
          Name = "AD-Domain-Services"
       }

		xWaitforDisk Disk2
        {
             DiskNumber = 2
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        cDiskNoRestart ADDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }

       xWaitForADDomain DscForestWait 
       { 
          DomainName = $DomainName 
          DomainUserCredential= $DomainCreds
          RetryCount = $RetryCount
          RetryIntervalSec = $RetryIntervalSec
          DependsOn = "[WindowsFeature]ADDSInstall", "[cDiskNoRestart]ADDataDisk", "[Script]AddADDSFeature"
      }

      xADDomainController ReplicaDC 
      { 
         DomainName = $DomainName 
         DomainAdministratorCredential = $DomainCreds 
		 SafemodeAdministratorPassword = $DomainCreds
         DatabasePath = "F:\NTDS"
         LogPath = "F:\NTDS"
         SysvolPath = "F:\SYSVOL"
         DependsOn = "[xWaitForADDomain]DScForestWait"
      }

      xPendingReboot Reboot
      { 
         Name = "RebootServer"
         DependsOn = "[xADDomainController]ReplicaDC"
      }
   }