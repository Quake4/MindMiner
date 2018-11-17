<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-ProfitLowerFloor ([Parameter(Mandatory)][eMinerType] $type) {
	[decimal] $result = 0
	if ($Config.MineAbove -and $Config.MineAbove."$type") {
		$tmp = $Config.MineAbove."$type";
		if ($tmp -is [PSCustomObject]) {
			$tmp | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
				$sign = $_
				$val = $Rates["BTC"] | Where-Object { $_[0] -eq $sign }
				if ($val) {
					$result = $tmp.$sign / ($val)[1]
				}
			}
		}
		else {
			$result = $Config.MineAbove."$type"
		}
	}
	$result
}