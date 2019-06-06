Function Get-OrionNodes {
    <#
    .SYNOPSIS
        Retrieve node info from SolarWinds Orion Network Performance Monitor (NPM).

    .DESCRIPTION
        Retrieve node info from SolarWinds Orion Network Performance Monitor (NPM) using
        the SolarWinds Information Service (SWIS) API.

        Depends upon the SwisPowerShell module.
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell

        Returns results as objects, suitable for formatting, filtering, or passing to pipeline
        for further processing.

        Results include the following fields. Refer to SWIS schema for details.
        http://solarwinds.github.io/OrionSDK/schema/index.html

        Orion.Nodes
            - AvgResponseTime 
            - NodeName 
            - Contact 
            - DetailsUrl 
            - IOSImage 
            - IOSVersion 
            - IPAddress 
            - Location 
            - MachineType 
            - NodeDescription 
            - PercentLoss 
            - PercentMemoryAvailable 
            - PercentMemoryUsed 
            - Status 
            - SysName 
            - Uri 
            - Vendor 
        
        NCM.EntityPhysical
            - EntityDescription
            - EntityName
            - Manufacturer
            - Model
            - Serial

    .PARAMETER Swis
        SolarWinds Information Service connection object, as returned from Connect-Swis.

        If not provided, Connect-Swis will prompt for username and password.

        Once supplied, $Swis remains in global scope, so future invocations of Get-OrionNodes
        will not prompt for credentials.
    
    .PARAMETER OrionServer
        IP address or FQDN of SolarWinds Orion NPM server.

        Once supplied, $OrionServer remains in global scope for future session use.

    .PARAMETER CustomProperties
        List of administratively-defined custom node properties to add to the SWQL query.
        See examples for details.

    .PARAMETER ExtraFields
        List of extra built-in schema fields to add to the SWQL query.
        Must prefix fields with table aliases below:
            - Orion.Nodes = N
            - NCM.EntityPhysical = E

        Refer to SWIS schema documentation for details.
        http://solarwinds.github.io/OrionSDK/schema/index.html

    .PARAMETER IPAddress
        List of node IP addresses to include in results.

    .PARAMETER IOSVersion
        List of IOS version strings to include in results.

    .PARAMETER IOSImage
        List of IOS image strings to include in results.

    .PARAMETER Location
        List of SNMP sysLocation strings to include in results.

    .PARAMETER Manufacturer
        List of manufacturer strings to include in results.

    .PARAMETER Model
        List of model strings to include in results.

    .PARAMETER NodeName
        List of node names (usually hostnames) to include in results.

    .PARAMETER NodeDescription
        List of node description strings to include in results.

    .PARAMETER OrderBy
        Field name to sort results by. Defaults to NodeName. See available fields above.

    .PARAMETER QueryOnly
        Returns the SWQL query string, without executing it against $OrionServer.
    
    .PARAMETER ResultLimit
        Integer limit of results to provide. Defaults to 0 (unlimited).

    .PARAMETER Serial
        List of serial number strings to include in results.

    .PARAMETER Status
        List of status codes to include in results. Defaults to 1 (up).
            - 1  = Up
            - 2  = Down
            - 3  = Warning
            - 4  = Shutdown
            - 9  = Unmanaged
            - 12 = Unreachable
            - 14 = Critical
            - 17 = Undefined

    .PARAMETER Vendor
        List of vendor strings to include in results.

    .EXAMPLE
        # Example 1: Simple report on all managed nodes

        Get-OrionNodes | ft nodename, ipaddress, serial

    .EXAMPLE
        # Example 2: Get all Cisco nodes on IOS 12.x

        Get-OrionNodes -Vendor Cisco -IOSVersion "12.*" | ft nodename

    .EXAMPLE
        # Example 3: Report on all unmanaged nodes

        Get-OrionNodes -Status 9 | ft nodename

    .EXAMPLE
        # Example 4: Report on all nodes with polling packet loss greater than 1%

        Get-OrionNodes | ? { $_.PercentLoss -gt 1}

    .EXAMPLE
        # Example 5: Working with custom properties
        # The custom node properties "DeviceType" and "DeviceClass" have been created in
        # Orion settings, and populated for each node.

        Get-OrionNodes -CustomProperties devicetype,deviceclass | ? { $_.devicetype -eq 'network' }

    .NOTES
        All string parameters support wildcards (*) for partial matching.

        Numeric comparisons are not natively implemented. Use PowerShell filtering instead.

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
        [string[]]$CustomProperties,
        [string[]]$ExtraFields,
        [string[]]$IPAddress,
        [string[]]$IOSVersion,
        [string[]]$IOSImage,
        [string[]]$Location,
        [string[]]$Manufacturer,
        [string[]]$Model,
        [string[]]$NodeName,
        [string[]]$NodeDescription,
        [string]$OrderBy = 'NodeName',
        [switch]$QueryOnly = $false,
        [int]$ResultLimit = 0,
        [string[]]$Serial,
        [string[]]$Status = 1,
        [string[]]$Vendor
    )
    Begin {
        Import-Module SwisPowerShell
        If (!$OrionServer) {
            $OrionServer = $Global:OrionServer = Read-Host 'Orion NPM IP or FQDN'
        }
        If (!$Swis) {
            $Swis = $Global:Swis = Connect-Swis -Hostname $OrionServer
        }
    }

    Process {

        # http://solarwinds.github.io/OrionSDK/schema/
        # Default Fields
        $DefaultFields = @(
            'E.EntityDescription'
            'E.EntityName'
            'E.Manufacturer'
            'E.Model'
            'E.Serial'
            'N.AvgResponseTime'
            'N.NodeName'
            'N.Contact'
            'N.DetailsUrl'
            'N.IOSImage'
            'N.IOSVersion'
            'N.IPAddress'
            'N.Location'
            'N.MachineType'
            'N.NodeDescription'
            'N.PercentLoss'
            'N.PercentMemoryAvailable'
            'N.PercentMemoryUsed'
            'N.Status'
            'N.SysName'
            'N.Uri'
            'N.Vendor'
        )

        # Extra fields
        If ($ExtraFields) {
            $AllFields = $DefaultFields + $ExtraFields
        } Else {
            $AllFields = $DefaultFields
        }

        # Custom Properties
        If ($CustomProperties) {
            ForEach ($Property in $CustomProperties) {
                $AllFields += "N.CustomProperties.${Property}"
            }
        }

        # Maps fields to parameters
        $FieldParamMap = @{
            'E.Manufacturer'     = 'Manufacturer'
            'E.Model'            = 'Model'
            'E.Serial'           = 'Serial'
            'N.Contact'          = 'Contact'
            'N.IOSImage'         = 'IOSImage'
            'N.IOSVersion'       = 'IOSVersion'
            'N.IPAddress'        = 'IPAddress'
            'N.Location'         = 'Location'
            'N.MachineType'      = 'MachineType'
            'N.NodeDescription'  = 'NodeDescription'
            'N.NodeName'         = 'NodeName'
            'N.Status'           = 'Status'
            'N.SysName'          = 'SysName'
            'N.Vendor'           = 'Vendor'
        }

        # Result limit
        $LimitString = ''
        If ($ResultLimit) {
            $LimitString = " TOP $ResultLimit"
        }
        
        # Build query
        $Query  = "SELECT${LimitString} $($AllFields -join ', ') "
        $Query += "FROM NCM.NodeProperties P "
        $Query += "INNER JOIN Orion.Nodes N ON P.CoreNodeID = N.NodeID "
        $Query += "LEFT JOIN NCM.EntityPhysical E ON E.NodeID = P.NodeID AND E.EntityClass = 3 "
        $Query += "WHERE "
        $WhereClause = @()

        # Where clause
        ForEach ($Item in $FieldParamMap.GetEnumerator()) {
            $Param = Get-Variable -Name $Item.Value -ErrorAction SilentlyContinue
            $WhereClause += Get-WhereClauseStatement $Item.Name $Param.Value
        }
    }

    End {

        # Finalize query
        $Query = "$Query $($WhereClause -join ' AND ') ORDER BY $OrderBy"

        If ($QueryOnly) {
            Return $Query
        } Else {
            # Obtain results
            $Results = Get-SwisData $Swis $Query
            Return $Results
        }
    }
}