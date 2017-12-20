configuration ConfigureSecondaryDc
{
   param
    (
		[Parameter(Mandatory)]
        [String]$ComputerName,

        [Parameter(Mandatory)]
        [String]$DNSServer,

        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )

    Import-DscResource -ModuleName xDisk, cDisk, xNetworking, xActiveDirectory, xPendingReboot, xComputerManagement

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)
	[System.Management.Automation.PSCredential ]$Creds = New-Object System.Management.Automation.PSCredential ($Admincreds.UserName, $Admincreds.Password)
	$Interface=Get-NetAdapter|Where Name -Like "Ethernet*"|Select-Object -First 1
    $InterfaceAlias=$($Interface.Name)

    Node localhost
    {
        LocalConfigurationManager
        {
            RebootNodeIfNeeded = $false
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
            DependsOn = "[xWaitForDisk]Disk2"
        }

		WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
			DependsOn = "[cDiskNoRestart]ADDataDisk"
        }

        WindowsFeature ADDSTools
        {
            Ensure = "Present"
            Name = "RSAT-ADDS-Tools"
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        WindowsFeature ADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSTools"
        }

        xDnsServerAddress DnsServerAddress
        {
            Address        = $DNSServer
            InterfaceAlias = $InterfaceAlias
            AddressFamily  = 'IPv4'
            DependsOn="[WindowsFeature]ADAdminCenter"
        }

		Script JoinDomain {
			SetScript =
            {
                Add-Computer -DomainName $using:DomainName -Credential $using:Creds
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = "[xDnsServerAddress]DnsServerAddress"
		}
        
        <#xComputer JoinDomain
        {
	      Name = $ComputerName
          DomainName = $DomainName
          Credential = $Creds # Credential to join to domain
          DependsOn = "[xDnsServerAddress]DnsServerAddress"
        }

        xADDomainController SecondaryDc
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "F:\NTDS"
            LogPath = "F:\NTDS"
            SysvolPath = "F:\SYSVOL"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

        Script UpdateDNSForwarder
        {
            SetScript =
            {
                Write-Verbose -Verbose "Getting DNS forwarding rule..."
                $dnsFwdRule = Get-DnsServerForwarder -Verbose
                if ($dnsFwdRule)
                {
                    Write-Verbose -Verbose "Removing DNS forwarding rule"
                    Remove-DnsServerForwarder -IPAddress $dnsFwdRule.IPAddress -Force -Verbose
                }
                Write-Verbose -Verbose "End of UpdateDNSForwarder script..."
            }
            GetScript =  { @{} }
            TestScript = { $false}
            DependsOn = "[WaitForADDomain]DscForestWait"
        }#>

        xPendingReboot RebootAfterPromotion {
            Name = "RebootAfterDCPromotion"
            DependsOn = "[Script]JoinDomain"
        }

    }
}
