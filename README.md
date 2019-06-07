# OrionToolkit

A PowerShell module for interacting with the SolarWinds Orion Network Performance Monitor (NPM) API.

Not published to the PowerShell Gallery during active development.

Requires the [`SwisPowerShell`](https://www.powershellgallery.com/packages/SwisPowerShell/) module.
Install from an Administrator PS5.0+ prompt:
`Install-Module -Name SwisPowerShell`

Cmdlets implemented so far:
* `Add-OrionNodes` - Add one or more new SNMPv3 managed nodes to NPM.
* `Get-OrionNodes` - Query nodes based on several parameters like hostname, status, vendor, and location.
* `Get-OrionSyslog` - Query syslog messages with advanced filtering.

See each cmdlet's `Get-Help` for details.

All cmdlets return objects suitable for formatting, filtering, or passing to pipeline for further procesesing.

Largely based on examples from [OrionSDK](https://github.com/solarwinds/OrionSDK).
