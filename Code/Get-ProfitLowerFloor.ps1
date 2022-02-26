<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-ProfitLowerFloor ([Parameter(Mandatory)][eMinerType] $type, [Parameter(Mandatory)][bool] $service) {
	[decimal] $result = 0
	if ($service) { return $result }
	if ($Config.LowerFloor -and $Config.LowerFloor."$type") {
		$tmp = $Config.LowerFloor."$type";
		if ($tmp -is [PSCustomObject]) {
			$tmp | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
				$val = $Rates[$_] | Where-Object { $_[0] -eq "BTC" }
				if ($val) {
					$result = $tmp.$_ * ($val)[1]
				}
			}
		}
		else {
			$result = $Config.LowerFloor."$type"
		}
	}
	$result
}