Function Add-OrionNodes {
    <#
    .SYNOPSIS
        Add nodes to Orion Network Performance Monitor (NPM).

    .DESCRIPTION
        Add one or more managed nodes and their respective interfaces to Orion NPM.

        Returns added nodes as objects, suitable for formatting, filtering, or passing to pipeline
        for further processing.

        Supports only SNMPv3 at this time.

        Add credential sets to Orion at All Settings > Credentials > Manage SNMPv3 Credentials.
        Pass the credential set name as $SNMPv3CredentialName.
        Alternatively, you may pass the numeric credential set ID as $SNMPv3CredentialID.

    .PARAMETER Swis
        SolarWinds Information Service connection object, as returned from Connect-Swis.

        If not provided, Connect-Swis will prompt for username and password.

        Once supplied, $Swis remains in global scope, so future invocations of Get-OrionNodes
        will not prompt for credentials.
    
    .PARAMETER OrionServer
        IP address or FQDN of SolarWinds Orion NPM server.

        Once supplied, $OrionServer remains in global scope for future session use.

    .PARAMETER NodeIP
        List of IP addresses of nodes to add.
        Import process will not add nodes already managed by NPM.

    .PARAMETER SNMPv3CredentialName
        Name of SNMPv3 credential set created in All Settings > Credentials > Manage SNMPv3 Credentials.
        Overrides $SNMPv3CredentialID, if provided.

    .PARAMETER SNMPv3CredentialID
        Integer ID of SNMPv3 credential set created in All Settings > Credentials > Manage SNMPv3 Credentials.
        Overridden by $SNMPv3CredentialName, if provided.

    .PARAMETER SetCaptionToHostname
        Sets node Caption property to discovered hostname (strips FQDN, if any).
        Defaults to $true.

    .PARAMETER CustomProperties
        Hash table of administratively-defined custom node properties to add to the node.
        Format: @{ 'CustomPropertyName' = 'Value' }

    .PARAMETER IncludeInterfaces
        List of wildcard strings. Interface descriptions matching these strings will be included
        in node management / monitoring.
        Defaults to all up interfaces ("*").

        By default, the import process adds all node interfaces in the "up" status.
        These interfaces are then monitored for traffic and up/down status.
        This usually includes some interfaces that you wish not to monitor.

    .PARAMETER ShowProgress
        Show status info during discovery process.
        Defaults to $true.

    .PARAMETER EngineID
        Integer ID of the Orion polling engine to add nodes to.
        Defaults to 1, as most deployments have only one engine.

    .EXAMPLE
        # Example 1: Add two nodes with progress, saving resulting output to $Results.

        $Results = Add-OrionNodes -NodeIP "10.100.20.10","10.100.20.11" -SNMPv3CredentialName "snmpv3_net"

    .EXAMPLE
        # Example 2: Add node with custom properties.
        # Custom node properties "Class" and "Type" have been created in Orion settings.

        $Results = Add-OrionNodes -NodeIP "10.100.20.10" -SNMPv3CredentialName "snmpv3_net" -CustomProperties @{'Class' = 'Network'; 'Type' = 'CoreAgg' }

    .NOTES
        SNMPv2c is not supported at this time.

    .LINK
        https://github.com/austind/oriontoolkit

    .FUNCTIONALITY
        PowerShell Language

    #>

    [CmdletBinding()]
    Param (
        [Parameter(HelpMessage="Solar Winds Information Service connection object")]
        [object]$Swis = $Global:Swis,
        [Parameter(HelpMessage="IP or FQDN of SolarWinds Orion NPM server")]
        [string]$OrionServer = $Global:OrionServer,
        [string[]]$NodeIP,
        [string]$SNMPv3CredentialName,
        [int]$SNMPv3CredentialID,
        [switch]$SetCaptionToHostname = $true,
        [hashtable]$CustomProperties,
        [string[]]$IncludeInterfaces = '*',
        [switch]$ShowProgress = $true,
        [int]$EngineID = 1
    )

    Begin {
        Import-Module SwisPowerShell
        If (!$Swis -and !$OrionServer) {
            $OrionServer = $Global:OrionServer = Read-Host 'Orion IP or FQDN'
        }
        If (!$Swis) {
            $Swis = $Global:Swis = Connect-Swis -Hostname $OrionServer
        }
        If ($SNMPv3CredentialName) {
            $Query = "SELECT TOP 1 ID FROM Orion.Credential WHERE Name = '$SNMPv3CredentialName'"
            $SNMPv3CredentialID = Get-SwisData $Swis $Query
        }
    }

    Process {
        $IpXml = ''
        $NodeIP | % {
            $IpXml += "`t`t<IpAddress>`n"
            $IpXml += "`t`t`t<Address>$_</Address>`n"
            $IpXml += "`t`t</IpAddress>`n"
        }

        # https://github.com/solarwinds/OrionSDK/wiki/Discovery
        $DeleteProfileAfterDiscoveryCompletes = "true"
        $CorePluginConfigurationContext = ([xml]"
        <CorePluginConfigurationContext xmlns='http://schemas.solarwinds.com/2012/Orion/Core' xmlns:i='http://www.w3.org/2001/XMLSchema-instance'>
	        <BulkList>
        $IpXml
	        </BulkList>
	        <Credentials>
		        <SharedCredentialInfo>
			        <CredentialID>$SNMPv3CredentialID</CredentialID>
			        <Order>1</Order>
		        </SharedCredentialInfo>
	        </Credentials>
	        <WmiRetriesCount>1</WmiRetriesCount>
	        <WmiRetryIntervalMiliseconds>1000</WmiRetryIntervalMiliseconds>
        </CorePluginConfigurationContext>
        ").DocumentElement
        $CorePluginConfiguration = Invoke-SwisVerb $Swis Orion.Discovery CreateCorePluginConfiguration @($CorePluginConfigurationContext)

        $InterfacesPluginConfigurationContext = ([xml]"
        <InterfacesDiscoveryPluginContext xmlns='http://schemas.solarwinds.com/2008/Interfaces' 
                                          xmlns:a='http://schemas.microsoft.com/2003/10/Serialization/Arrays'>
            <AutoImportVirtualTypes>
                <a:string>Virtual</a:string>
            </AutoImportVirtualTypes>
            <AutoImportVlanPortTypes>
                <a:string>Trunk</a:string>
            </AutoImportVlanPortTypes>
            <UseDefaults>false</UseDefaults>
        </InterfacesDiscoveryPluginContext>
        ").DocumentElement
        $InterfacesPluginConfiguration = Invoke-SwisVerb $Swis Orion.NPM.Interfaces CreateInterfacesPluginConfiguration @($InterfacesPluginConfigurationContext)

        $StartDiscoveryContext = ([xml]"
        <StartDiscoveryContext xmlns='http://schemas.solarwinds.com/2012/Orion/Core' xmlns:i='http://www.w3.org/2001/XMLSchema-instance'>
	        <Name>Script Discovery $([DateTime]::Now)</Name>
	        <EngineId>$EngineID</EngineId>
	        <JobTimeoutSeconds>3600</JobTimeoutSeconds>
	        <SearchTimeoutMiliseconds>2000</SearchTimeoutMiliseconds>
	        <SnmpTimeoutMiliseconds>2000</SnmpTimeoutMiliseconds>
	        <SnmpRetries>3</SnmpRetries>
	        <RepeatIntervalMiliseconds>1500</RepeatIntervalMiliseconds>
	        <SnmpPort>161</SnmpPort>
	        <HopCount>0</HopCount>
	        <PreferredSnmpVersion>SNMP2c</PreferredSnmpVersion>
	        <DisableIcmp>false</DisableIcmp>
	        <AllowDuplicateNodes>false</AllowDuplicateNodes>
	        <IsAutoImport>true</IsAutoImport>
	        <IsHidden>$DeleteProfileAfterDiscoveryCompletes</IsHidden>
	        <PluginConfigurations>
		        <PluginConfiguration>
			        <PluginConfigurationItem>$($CorePluginConfiguration.InnerXml)</PluginConfigurationItem>
                    <PluginConfigurationItem>$($InterfacesPluginConfiguration.InnerXml)</PluginConfigurationItem>
		        </PluginConfiguration>
	        </PluginConfigurations>
        </StartDiscoveryContext>
        ").DocumentElement
        $DiscoveryProfileID = (Invoke-SwisVerb $Swis Orion.Discovery StartDiscovery @($StartDiscoveryContext)).InnerText

        # Wait until the discovery completes
        Do {
            If ($ShowProgress) {
                $Activity = "Discovery profile #${DiscoveryProfileID}"
                Write-Progress -Activity $Activity -Status "Running discovery.." }
            Start-Sleep -Seconds 1
            $Status = Get-SwisData $Swis "SELECT Status FROM Orion.DiscoveryProfiles WHERE ProfileID = @profileId" @{profileId = $DiscoveryProfileID}
        } While ($Status -eq 1)

        # If $DeleteProfileAfterDiscoveryCompletes is true, then the profile will be gone at this point, but we can still get the result from Orion.DiscoveryLogs
        $Result = Get-SwisData $Swis "SELECT Result, ResultDescription, ErrorMessage, BatchID FROM Orion.DiscoveryLogs WHERE ProfileID = @profileId" @{profileId = $DiscoveryProfileID}
        $ResultString = Switch ($Result.Result) {
            0 {"Unknown"}
            1 {"InProgress"}
            2 {"Finished"}
            3 {"Error"}
            4 {"NotScheduled"}
            5 {"Scheduled"}
            6 {"NotCompleted"}
            7 {"Canceling"}
            8 {"ReadyForImport"}
        }
        
        If ($ShowProgress) {
            $Status = "$($Result.ResultDescription): $($Result.ErrorMessage)"
            Write-Progress -Activity $Activity -Status $Status
        }

        # If discovery completed successfully
        If ($Result.Result -eq 2) {
            $Results = @()

            # Find out what objects were discovered
            $Discovered = Get-SwisData $Swis "SELECT EntityType, DisplayName, NetObjectID FROM Orion.DiscoveryLogItems WHERE BatchID = @batchId" @{batchId = $Result.BatchID}
            If ($ShowProgress) {
                $Status = "$($Discovered.Count) items imported."
                Write-Progress -Activity $Activity -Status $Status
            }

            $NodeNetObjectIds = $Discovered | ? { $_.EntityType -eq 'Orion.Nodes' }
            ForEach ($NodeNetObjectId in $NodeNetObjectIds) {

                # Node properties
                $NodeId = $NodeNetObjectId.NetObjectId.split(':')[1]
                $NodeUri = "swis://$OrionServer/Orion/Orion.Nodes/NodeID=$NodeId"
                $NodeProps = Get-SwisObject $Swis -Uri $NodeUri
                $Hostname = $NodeProps['Caption'].Split('.')[0]

                # Truncate caption
                If ($SetCaptionToHostname) {
                    $NewNodeProps = @{
                        Caption = $Hostname
                    }
                    If ($ShowProgress) {
                        $Status = "Setting Caption to $Hostname"
                        Write-Progress -Activity $Activity -Status $Status
                    }
                    Set-SwisObject $Swis -Uri $NodeUri -Properties $NewNodeProps
                }

                # Custom properties
                If ($CustomProperties) {
                    $CustomPropsUri = "$NodeUri/CustomProperties"
                    If ($ShowProgress) {
                        $Status = "Setting custom properties for $Hostname"
                        Write-Progress -Activity $Activity -Status $Status
                    }
                    Set-SwisObject $Swis -Uri $CustomPropsUri -Properties $CustomProperties
                }

                # Included interfaces
                $Interfaces = Get-SwisData $Swis -Query "SELECT Uri, DisplayName FROM Orion.NPM.Interfaces WHERE NodeId = '$NodeId'"
                $InterfaceResults = @()
                ForEach ($Interface in $Interfaces) {
                    ForEach ($Pattern in $IncludeInterfaces) {
                        If ($Interface.DisplayName -notlike $Pattern) {
                            If ($ShowProgress) {
                                $Status = "Removing excluded interface from ${Hostname}: $($Interface.DisplayName)"
                                Write-Progress -Activity $Activity -Status $Status
                            }
                            Remove-SwisObject $Swis -Uri $Interface.Uri
                        } Else {
                            $InterfaceResults += $Interface
                        }
                    }
                }

                # Results
                $Result = [PsCustomObject]@{
                    'NodeName' = $Hostname
                    'NodeID' = $NodeProps.NodeID
                    'IPAddress' = $NodeProps.IPAddress
                    'Interfaces' = $InterfaceResults
                }
                $Results += $Result
            }
        }
    }

    End {
        If ($ShowProgress) {
            $Status = "Import complete."
            Write-Progress -Activity $Activity -Status $Status
        }
        Return $Results
    }
}