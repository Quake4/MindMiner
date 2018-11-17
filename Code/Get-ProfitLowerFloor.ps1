<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-ProfitLowerFloor ([Parameter(Mandatory)][eMinerType] $type) {
	[decimal] $result = 0
	if ($Config.MineAbove -and $Config.MineAbove."$type") {
		$result = $Config.MineAbove."$type"
	}
	$result
}