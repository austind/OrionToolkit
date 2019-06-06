Function Get-WhereClauseStatement {
    Param (
        [string]$Name,
        [string[]]$Values = $null,
        [string]$Operator = '='
    )
    If ($Values) {
        $ClauseStatement = @()
        ForEach ($Value in $Values) {
            If ($Operator -match '\!') {
                $Join = 'AND'
            } Else {
                $Join = 'OR'
            }
            If ($Value -match '\*') {
                If ($Operator -match '\!') {
                    $ValueOperator = 'NOT LIKE'
                } Else {
                    $ValueOperator = 'LIKE'
                }
                $Value = $Value -replace '\*','%'
            } Else {
                $ValueOperator = $Operator
            }
            $ClauseStatement += "$Name $ValueOperator '$Value'"
        }
        Return "( $($ClauseStatement -join " $Join ") )"
    }
}