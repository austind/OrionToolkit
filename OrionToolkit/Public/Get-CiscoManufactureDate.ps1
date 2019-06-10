Function Get-CiscoManufactureDate {
<#
    .SYNOPSIS
    Parses a modern Cisco serial number into an approximate date of
    manufacture.

    .DESCRIPTION
    Modern Cisco serial numbers encode both the year and the week of
    manufacture. Get-CiscoManufactureDate returns a corresponding DateTime
    object given a Cisco serial number, accurate to within about 7 days
    of actual manufacture. See NOTES section for further info on precision.

    .PARAMETER Serial 
    A string of the serial number to be parsed.

    .EXAMPLE
    Basic usage:

    Get-CiscoManufactureDate -Serial FDO1338Y0Q9

    Prints:

    Wednesday, September 23, 2009 12:00:00 AM

    .EXAMPLE
    Also accepts pipeline input:

    'FDO1338Y0Q9' | Get-CiscoManufactureDate

    .EXAMPLE
    Print the date in a more appropriate format:
    $Date = Get-CiscoManufactureDate -Serial FDO1338Y0Q9
    Get-Date $Date -Format 'Y'

    Prints:

    September 2009

    .NOTES
    Based on info derived from:
    https://supportforums.cisco.com/t5/lan-switching-and-routing/cisco-serial-number-lookups/m-p/1375239/highlight/true#M127040

    The returned date conveys as much precision as the serial number provides,
    therefore the returned date is accurate within 7 days of actual
    manufacture.

    The post above implies otherwise, but in reality, a given week of the year
    may fall in a different month from one year to another. Furthermore, a
    given week may overlap two months; e.g., week 40 in 2003 overlaps both 
    September and October. Rather than rely upon the static week-to-month
    mapping provided in the post above, Get-CiscoManufactureDate uses DateTime's
    AddDays() method to approximate the manufacture date. Unit tests show this
    approach produces accurate results, as compared to the week-of-year calendar
    provided by https://www.epochconverter.com/weeks/2003.

    Bottom line:

     - Get-CiscoManufactureDate may produce results inconsistent with
       the assumptions in the Cisco support post above, but with greater
       precision.

     - The year of manufacture is unambiguous and therefore always accurate.

     - The month of manufacture is derived from the week of manufacture,
       and is somewhat ambiguous due to a 7-day margin of error.
       
     - The day and time of manufacture, as returned in the DateTime object,
       should never be considered accurate.

    MIT License

    Copyright (c) 2017 Austin de Coup-Crank <austindcc@gmail.com>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

#>
    [CmdletBinding()]
    Param (
        [Parameter(
            Position = 0, 
            Mandatory = $true, 
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true,
            HelpMessage = 'A modern Cisco serial number; e.g., FDO1338Y0Q9')
        ]
        [ValidateNotNull()]
        [string]$Serial
    )
    
    $SerialRegex = '^\s*[a-z]{3}(?<YearCode>[0-9]{2})(?<WeekCode>(0[1-9]|[1-4][0-9]|5[0-2]))[a-z0-9]{4}\s*$'
    If ($Serial -match $SerialRegex) {
        $MfgYear = 1996 + [int]$Matches['YearCode']
        $MfgDate = Get-Date -Date "${MfgYear}-01-01"
        Return $MfgDate.AddDays((7 * [int]$Matches['WeekCode']) - 1)
    } Else {
        Throw "Provided serial number (${Serial}) does not look like the kind of Cisco serial number that encodes manufacture date."
    }
}