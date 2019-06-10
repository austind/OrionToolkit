Function Get-OrionSyslog {
    <#
    .SYNOPSIS
        Retrieve syslog messages from SolarWinds Orion Network Performance Monitor (NPM).

    .DESCRIPTION
        Retrieve syslog messages from SolarWinds Orion Network Performance Monitor (NPM) using
        the SolarWinds Information Service (SWIS) API.

        Defaults to retrieving all messages, for all nodes, for the past hour.

        Depends upon the SwisPowerShell module.
        https://github.com/solarwinds/OrionSDK/wiki/PowerShell

        Returns results as objects, suitable for formatting, filtering, or passing to pipeline
        for further processing.

        Results include the following fields. Refer to SWIS schema for details.
        http://solarwinds.github.io/OrionSDK/schema/index.html

        Orion.Nodes
            - NodeName
            - Vendor
        
        Orion.SysLog
            - Acknowledged
            - DateTime
            - EngineID
            - FirstIPInMessage
            - Hostname
            - IPAddress
            - MacInMessage
            - Message
            - MessageID
            - MessageType
            - ObservationSeverity
            - SecIPInMessage
            - SysLogFacility
            - SysLogSeverity
            - SysLogTag

    .PARAMETER Swis
        SolarWinds Information Service connection object, as returned from Connect-Swis.

        If not provided, Connect-Swis will prompt for username and password.

        Once supplied, $Swis remains in global scope, so future invocations of Get-OrionSyslog
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
            - Orion.SysLog = S

        Refer to SWIS schema documentation for details.
        http://solarwinds.github.io/OrionSDK/schema/index.html

    .PARAMETER IncludeNodeName
        List of node names (hostnames) to include in results.

    .PARAMETER ExcludeNodeName
        List of node names (hostnames) to exclude from results.

    .PARAMETER IncludeVendor
        List of vendor strings to include in results.

    .PARAMETER ExcludeVendor
        List of vendor strings to exclude from results.

    .PARAMETER IncludeMessage
        List of message strings to include in results. Wildcards are helpful.

    .PARAMETER ExcludeMessage
        List of message strings to exclude from results. Wildcards are helpful.

    .PARAMETER IncludeMessageType
        List of message type strings to include in results.

    .PARAMETER ExcludeMessageType
        List of message type strings to exclude from results.
        Defaults to the following MessageTypes:
            - SEC_LOGIN-5-LOGIN_SUCCESS
            - SYS-5-CONFIG_I
            - SYS-6-LOGGINGHOST_STARTSTOP
            - ADJ-3-RESOLVE_REQ # Cisco Bug CSCtx86444

    .PARAMETER ExcludeEmptyMessageType
        Exclude empty MessageType strings from results.
        Defaults to $true.

    .PARAMETER ExcludeLinkStatus
        Exclude link state change messages from results. Based on Cisco MessageTypes.
        Defaults to $true.

    .PARAMETER ExcludePoEStatus
        Exclude inline power (PoE) status change messages from results. Based on Cisco MessageTypes.
        Defaults to $true.

    .PARAMETER IncludeAllMessageTypes
        Overrides all message type filtering, such as $ExcludeLinkStatus.
        Overrides $HardwareReport.

    .PARAMETER MinSeverityKeyword
        Keyword for lowest syslog severity to include in results.
        Overrides $MinSeverity.

        Keywords in decreasing order of severity:
        - emerg
        - alert
        - crit
        - err
        - warning
        - notice
        - info
        - debug

    .PARAMETER MinSeverity
        Numeric value for lowest syslog severity to include in results.
        Overridden by $MaxSeverityKeyword.

        Severity increases as value decreases. Passing $MinSeverity = 4 means anything
        below Warning severity will be excluded from results.

    .PARAMETER MaxSeverityKeyword
        Keyword for highest syslog severity to include in results.
        Overrides $MaxSeverity.

        Keywords in decreasing order of severity:
        - emerg
        - alert
        - crit
        - err
        - warning
        - notice
        - info
        - debug

    .PARAMETER MaxSeverity
        Numeric value for highest syslog severity to include in results.
        Overridden by $MaxSeverityKeyword.

        Severity increases as value decreases. Passing $MaxSeverity = 4 means anything
        above Warning severity will be excluded from results.

    .PARAMETER PastHours
        Include messages from the past N hours in results.
        Overrides $Start and $End values, if given.

    .PARAMETER PastDays
        Include messages from the past N days in results.
        Overrides $Start and $End values, if given.

    .PARAMETER Start
        DateTime object from which to begin results.
        Overridden by $PastHours or $PastDays, if given.

    .PARAMETER End
        DateTime object from which to end results.
        Overridden by $PastHours or $PastDays, if given.

    .PARAMETER ResultLimit
        Integer limit of results to provide.
        Defaults to 0 (unlimited).

    .PARAMETER SanitizeMessage
        Strips extraneous prefix characters and whitespace from message string
        Defaults to $true.

    .PARAMETER ExcludeDuplicates
        Results will include only one instance of a given message for each NodeName.
        Defaults to $true.

    .PARAMETER HardwareReport
        Includes MessageTypes associated with hardware status. Based on Cisco MessageTypes.

    .PARAMETER QueryOnly
        Returns the SWQL query string, without executing it against $OrionServer.
    
    .EXAMPLE
        # Example 1: Get all syslog messages from the past hour

        Get-OrionSyslog | ft DateTime, NodeName, Message

    .EXAMPLE
        # Example 2: Get syslog messages from Cisco devices starting with "core" from the past hour

        Get-OrionSyslog -Vendor Cisco -IncludeNodeName "core*" | ft DateTime, NodeName, Message

    .NOTES
        All string parameters support wildcards (*) for partial matching.

    .LINK
        https://github.com/austind/oriontoolkit

    .FUNCTIONALITY
        PowerShell Language

    #>

    [CmdletBinding()]
    Param (
        [Parameter(HelpMessage="Solar Winds Information Service connection object")]
        [object]$Swis = $Global:Swis,
        [Parameter(HelpMessage="IP or FQDN of SolarWinds Orion syslog server")]
        [string]$OrionServer = $Global:OrionServer,
        [string[]]$CustomProperties,
        [string[]]$ExtraFields,
        [string[]]$IncludeNodeName,
        [string[]]$ExcludeNodeName,
        [string[]]$IncludeVendor,
        [string[]]$ExcludeVendor,
        [string]$IncludeMessage,
        [string]$ExcludeMessage,
        [string[]]$IncludeMessageType,
        [string[]]$ExcludeMessageType = @(
            'SEC_LOGIN-5-LOGIN_SUCCESS'
            'SYS-5-CONFIG_I'
            'SYS-6-LOGGINGHOST_STARTSTOP'
            'ADJ-3-RESOLVE_REQ' # Cisco Bug CSCtx86444
        ),
        [switch]$ExcludeEmptyMessageType = $true,
        [switch]$ExcludeLinkStatus = $true,
        [switch]$ExcludePoEStatus = $true,
        [switch]$IncludeAllMessageTypes = $false,
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug')]
        [string]$MinSeverityKeyword,
        [ValidateRange(0,7)]
        [int]$MinSeverity = 7,
        [ValidateSet('emerg','alert','crit','err','warning','notice','info','debug')]
        [string]$MaxSeverityKeyword,
        [ValidateRange(0,7)]
        [int]$MaxSeverity = 0,
        [int]$PastHours,
        [int]$PastDays,
        [datetime]$Start = ((Get-Date).AddHours(-1)),
        [datetime]$End = (Get-Date),
        [int]$ResultLimit = 0,
        [switch]$SanitizeMessage = $true,
        [switch]$ExcludeDuplicates = $true,
        [switch]$HardwareReport = $false,
        [switch]$QueryOnly = $false
    )

    Begin {
        Import-Module SwisPowerShell
        If (!$Swis -and !$OrionServer) {
            $OrionServer = $Global:OrionServer = Read-Host 'Orion IP or FQDN'
        }
        If (!$Swis) {
            $Swis = $Global:Swis = Connect-Swis -Hostname $OrionServer
        }

        $FieldParamMap = @(
            @{'Field' = 'NodeName';    'Operator' =  '='; 'Param' = 'IncludeNodeName'    }
            @{'Field' = 'NodeName';    'Operator' = '!='; 'Param' = 'ExcludeNodeName'    }
            @{'Field' = 'Vendor';      'Operator' =  '='; 'Param' = 'IncludeVendor'      }
            @{'Field' = 'Vendor';      'Operator' = '!='; 'Param' = 'ExcludeVendor'      }
            @{'Field' = 'Message';     'Operator' =  '='; 'Param' = 'IncludeMessage'     }
            @{'Field' = 'Message';     'Operator' = '!='; 'Param' = 'ExcludeMessage'     }
            @{'Field' = 'MessageType'; 'Operator' =  '='; 'Param' = 'IncludeMessageType' }
            @{'Field' = 'MessageType'; 'Operator' = '!='; 'Param' = 'ExcludeMessageType' }
            @{'Field' = 'Severity';    'Operator' = '<='; 'Param' = 'MinSeverity'        }
            @{'Field' = 'Severity';    'Operator' = '>='; 'Param' = 'MaxSeverity'        }
        )

        $SeverityMap = @{
            'emerg'   = 0
            'alert'   = 1
            'crit'    = 2
            'err'     = 3
            'warning' = 4
            'notice'  = 5
            'info'    = 6
            'debug'   = 7
        }
    }

    Process {

        # Default fields
        $DefaultFields = @(
            'N.NodeName'
            'N.Vendor'
            'S.Acknowledged'
            'S.DateTime'
            'S.EngineID'
            'S.FirstIPInMessage'
            'S.Hostname'
            'S.IPAddress'
            'S.MacInMessage'
            'S.Message'
            'S.MessageID'
            'S.MessageType'
            'S.ObservationSeverity'
            'S.SecIPInMessage'
            'S.SysLogFacility AS Facility'
            'S.SysLogSeverity AS Severity'
            'S.SysLogTag'
        )

        # Extra fields
        If ($ExtraFields) {
            $AllFields = $DefaultFields + $ExtraFields
        } Else {
            $AllFields = $DefaultFields
        }

        # Custom properties
        If ($CustomProperties) {
            ForEach ($Property in $CustomProperties) {
                $AllFields += "N.CustomProperties.${Property}"
            }
        }

        # Include all message types
        If ($IncludeAllMessageTypes) {
            $HardwareReport = $false
            $ExcludeEmptyMessageType = $false
            $ExcludeLinkStatus = $false
            $ExcludePoEStatus = $false
        }

        # Hardware report
        If ($HardwareReport) {
            $IncludeMessageType += @(
                'HARDWARE-2-FAN_ERROR'
                'HARDWARE-2-THERMAL_WARNING'
                'PLATFORM-3-ELEMENT_CRITICAL'
                'PLATFORM-4-ELEMENT_WARNING'
                'PLATFORM_ENV-1-FAN'
                'PLATFORM_ENV-1-TEMP'
                'SFF8472-3-THRESHOLD_VIOLATION'
            )
        }

        # Exclude blank message types
        If ($ExcludeEmptyMessageType) {
            $ExcludeMessageType += @(
                ''
            )
        }

        # Exclude link status
        If ($ExcludeLinkStatus) {
            $ExcludeMessageType += @(
                'LINEPROTO-5-UPDOWN'
                'LINK-3-UPDOWN'
                'LINK-5-CHANGED'
            )
        }

        # Exclude PoE events
        If ($ExcludePoEStatus) {
            $ExcludeMessageType += @(
                'ILPOWER-5-IEEE_DISCONNECT'
                'ILPOWER-5-POWER_GRANTED'
                'ILPOWER-7-DETECT'
            )
        }

        # Severity
        If ($MinSeverityKeyword) {
            $MinSeverity = $SeverityMap[$MinSeverityKeyword]
        }
        If ($MaxSeverityKeyword) {
            $MaxSeverity = $SeverityMap[$MaxSeverityKeyword]
        }

        # Result limit
        $LimitString = ''
        If ($ResultLimit) {
            $LimitString = " TOP $ResultLimit"
        }
        
        # Build query
        $Query  = "SELECT${LimitString} $($AllFields -join ', ') FROM Orion.SysLog S "
        $Query += "INNER JOIN Orion.Nodes N ON S.NodeID = N.NodeID WHERE "
        $WhereClause = @()

        # Past hours
        If ($PastHours) {
            $PastHoursDate = $(Get-Date ((Get-Date).AddHours(-($PastHours))) -Format g)
            $WhereClause += Get-WhereClauseStatement 'DateTime' $PastHoursDate '>='
        }
        
        # Past days
        If ($PastDays) {
            $PastDaysDate = $(Get-Date ((Get-Date).AddDays(-($PastDays))) -Format g)
            $WhereClause += Get-WhereClauseStatement 'DateTime' $PastDaysDate '>='
        }

        # Start
        If (!$PastHours -and !$PastDays -and $Start) {
            $WhereClause += Get-WhereClauseStatement 'DateTime' $(Get-Date $Start -Format g) '>='
        }

        # End
        If (!$PastHours -and !$PastDays -and $End) {
            $WhereClause += Get-WhereClauseStatement 'DateTime' $(Get-Date $End -Format g) '<='
        }

        # Where clause
        ForEach ($Item in $FieldParamMap) {
            $Param = Get-Variable -Name $Item.Param -ErrorAction SilentlyContinue
            $WhereClause += Get-WhereClauseStatement $Item.Field $Param.Value $Item.Operator
        }
    }

    End {

        # Finalize query
        $Query = $Query + ($WhereClause -join ' AND ') + " ORDER BY DateTime DESC"

        # Debug output
        If ($QueryOnly) {
            Return $Query
        } Else {

            # Obtain results
            $Results = Get-SwisData $Swis $Query

            # Sanitize message
            If ($SanitizeMessage) {
                ForEach ($Result in $Results) {

                    # Strip leading event ID (useless without context)
                    $Result.Message = $Result.Message -replace "^\d+:\s*",""

                    # Strip leading characters
                    $Result.Message = $Result.Message -replace "^[\*\.]\s*",""

                    # Collapse excess whitespace
                    $Result.Message = $Result.Message -replace "\s{2,}"," "
                }
            }

            # Exclude duplicates
            If ($ExcludeDuplicates) {
                    $Results = $Results | Sort NodeName, Message -Unique
                    $Results = $Results | Sort DateTime -Descending
            }

            Return $Results
        }
    }
}