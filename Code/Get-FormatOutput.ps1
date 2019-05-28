<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-FormatDualSpeed([bool] $active, [decimal] $speed, [string] $hasdual, [decimal] $dual) {
	$result = "Unknown"
	if ($speed -eq 0) {
		if ($active) {
			$result = if ($global:HasConfirm -eq $true) { "Benchmarking" } else { "Need bench" }
		}
	}
	else {
		$result = "$([MultipleUnit]::ToString($speed))"
		if (![string]::IsNullOrWhiteSpace($hasdual)) {
			$dualstr = "$([MultipleUnit]::ToString($dual))"
			if ([char]::IsLetter($result[$result.Length - 1]) -and $result[$result.Length - 1] -eq $dualstr[$dualstr.Length - 1]) {
				$result = $result.Remove($result.Length - 1)
				$result =  "$($result.Trim())+$dualstr"
			}
			else {
				$result += "+$dualstr"
			}
		}
	}
	$result
}

function Get-FormatMiners {
	$AllMinersFormatTable = [Collections.ArrayList]::new()

	$AllMinersFormatTable.AddRange(@(
		@{ Label="Miner"; Expression = {
			$uniq =  $_.Miner.GetUniqueKey()
			$str = if ($_.SwitchingResistance) { "%" } elseif ($_.Speed -gt 0 -and $_.Profit -lt (Get-ProfitLowerFloor ($_.Miner.Type))) { "_" } else { [string]::Empty }
			($ActiveMiners.Values | Where-Object { $_.State -ne [eState]::Stopped } | ForEach-Object {
				if ($_.Miner.GetUniqueKey() -eq $uniq) {
					if ($_.State -eq [eState]::Running) { $str = "+" }
					elseif ($_.State -eq [eState]::NoHash) { $str = "-" }
					elseif ($_.State -eq [eState]::Failed) { $str = "!" }
					else { $str = [string]::Empty } } })
			$str + $_.Miner.Name } }
		@{ Label="Algorithm"; Expression = { "$($_.Miner.Algorithm)$(if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) { "+$($_.Miner.DualAlgorithm)" } else { [string]::Empty })" } }
		@{ Label="Speed, H/s"; Expression = { Get-FormatDualSpeed $true $_.Speed $_.Miner.DualAlgorithm $_.DualSpeed }; Alignment="Right" }
	))

	if ($Config.DevicesStatus -and (Get-ElectricityPriceCurrency)) {
		if ($Config.ElectricityConsumption) {
			$AllMinersFormatTable.AddRange(@(
				@{ Label="Raw Profit"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { "{0:N8}" -f $_.ProfitRaw } }; Alignment="Right" }
			))
		}
		$AllMinersFormatTable.AddRange(@(
			@{ Label="Electricity"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { "{0:N8}" -f $_.Power } }; Alignment="Right" }
		))
	}

	$AllMinersFormatTable.AddRange(@(
		@{ Label="BTC/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit } }; FormatString = "N8" }
	))

	# hack
	for ($i = 0; $i -lt $Rates["BTC"].Count; $i++) {
		if ($i -eq 0 -and "BTC" -ne $Rates["BTC"][0][0]) {
			$AllMinersFormatTable.AddRange(@(
				@{ Label="$($Rates["BTC"][0][0])/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * $Rates["BTC"][0][1] } }; FormatString = "N$($Config.Currencies[0][1])" }
			))	
		}
		elseif ($i -eq 1) {
			$AllMinersFormatTable.AddRange(@(
				@{ Label="$($Rates["BTC"][1][0])/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * $Rates["BTC"][1][1] } }; FormatString = "N$($Config.Currencies[1][1])" }
			))	
		}
		elseif ($i -eq 2) {
			$AllMinersFormatTable.AddRange(@(
				@{ Label="$($Rates["BTC"][2][0])/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * $Rates["BTC"][2][1] } }; FormatString = "N$($Config.Currencies[2][1])" }
			))	
		}
	}

	$AllMinersFormatTable.AddRange(@(
		@{ Label="BTC/GH/Day"; Expression = { $_.Price * 1000000000 }; FormatString = "N8" }
		@{ Label="Pool"; Expression = { $_.Miner.Pool } }
		@{ Label="ExtraArgs"; Expression = { $_.Miner.ExtraArgs } }
	))
	
	$AllMinersFormatTable
}

function Get-FormatActiveMiners([bool] $full) {
	$ActiveMinersFormatTable = [Collections.ArrayList]::new()

	$ActiveMinersFormatTable.AddRange(@(
		@{ Label="Type"; Expression = { $_.Miner.Type } }
		@{ Label="Pool"; Expression = { $_.Miner.Pool } }
		@{ Label="Algorithm"; Expression = { "$($_.Miner.Algorithm)$(if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) { "+$($_.Miner.DualAlgorithm)" } else { [string]::Empty })" } }
		@{ Label="Speed, H/s"; Expression = { Get-FormatDualSpeed $false $_.GetSpeed($false) $_.Miner.DualAlgorithm $_.GetSpeed($true) }; Alignment="Right"; }
	))

	if ($Config.DevicesStatus) {
		$ActiveMinersFormatTable.AddRange(@(
			@{ Label="Power, W"; Expression = { $p = $_.GetPower(); if ($p -eq 0) { "Unknown" } else { "{0:N1}" -f $p } }; Alignment="Right"; }
		))
	}

	$ActiveMinersFormatTable.AddRange(@(
		@{ Label="Run Time"; Expression = { [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) }; Alignment = "Right" }
		@{ Label="Run"; Expression = { if ($_.Run -eq 1) { "Once" } else { $_.Run } }; Alignment = "Right" }
	))

	if ($full) {
		$ActiveMinersFormatTable.AddRange(@(
			@{ Label="Error"; Expression = { if ($_.ErrorAnswer -eq 0) { "None" } else { $_.ErrorAnswer } }; Alignment = "Right" } 
		))
	}

	$ActiveMinersFormatTable.AddRange(@(
		@{ Label="Command"; Expression = { $_.Miner.GetCommandLine() } }
	))

	$ActiveMinersFormatTable
}

function Get-FormatActiveMinersWeb {
	$ActiveMinersFormatTable = [Collections.ArrayList]::new()

	$ActiveMinersFormatTable.AddRange(@(
		@{ Label="Type"; Expression = { $_.Miner.Type } }
		@{ Label="Pool"; Expression = { $_.Miner.Pool } }
		@{ Label="Algorithm"; Expression = { "$($_.Miner.Algorithm)$(if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) { "+$($_.Miner.DualAlgorithm)" } else { [string]::Empty })" } }
		@{ Label="Speed, H/s"; Expression = { Get-FormatDualSpeed $false $_.GetSpeed($false) $_.Miner.DualAlgorithm $_.GetSpeed($true) } }
		@{ Label="Run Time"; Expression = { [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) } }
		@{ Label="Run"; Expression = { if ($_.Run -eq 1) { "Once" } else { $_.Run } } }
		@{ Label="Command"; Expression = { $_.Miner.GetCommandLine() } }
	))

	$ActiveMinersFormatTable
}

function Get-FormatActiveMinersApi {
	$ActiveMinersFormatTable = [Collections.ArrayList]::new()

	$ActiveMinersFormatTable.AddRange(@(
		@{ Label="type"; Expression = { $_.Miner.Type } }
		@{ Label="pool"; Expression = { $_.Miner.Pool } }
		@{ Label="miner"; Expression = { $_.Miner.Name } }
		@{ Label="algorithm"; Expression = { "$($_.Miner.Algorithm)$(if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) { "+$($_.Miner.DualAlgorithm)" } else { [string]::Empty })" } }
		@{ Label="speed"; Expression = { [decimal]::Round($_.GetSpeed($false), 2) } }
		@{ Label="speeddual"; Expression = { [decimal]::Round($_.GetSpeed($true), 2) } }
		@{ Label="benchmarking"; Expression = { $_.Action -eq [eAction]::Benchmark } }
		@{ Label="runtime"; Expression = { [decimal]::Round($_.CurrentTime.Elapsed.TotalSeconds) } }
		@{ Label="profit"; Expression = { $cur = $_; $miner = $AllMiners | Where-Object { $_.Miner.GetUniqueKey() -eq $cur.Miner.GetUniqueKey() -and $_.Miner.Type -eq $cur.Miner.Type } | Select-Object -First 1; if ($miner) { [decimal]::Round($miner.Profit, 8) } else { $null } } }
	))

	$ActiveMinersFormatTable
}

function Get-FormatActiveMinersOnline {
	$ActiveMinersFormatTable = [Collections.ArrayList]::new()

	$ActiveMinersFormatTable.AddRange(@(
		@{ Label="type"; Expression = { $_.Miner.Type } }
		@{ Label="pool"; Expression = { $_.Miner.Pool } }
		@{ Label="miner"; Expression = { $_.Miner.Name } }
		@{ Label="algorithm"; Expression = { "$($_.Miner.Algorithm)$(if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) { "+$($_.Miner.DualAlgorithm)" } else { [string]::Empty })" } }
		@{ Label="speed"; Expression = { Get-FormatDualSpeed $false $_.GetSpeed($false) $_.Miner.DualAlgorithm $_.GetSpeed($true) } }
		@{ Label="speedraw"; Expression = { [decimal]::Round($_.GetSpeed($false), 2) } }
		@{ Label="speedrawdual"; Expression = { [decimal]::Round($_.GetSpeed($true), 2) } }
		@{ Label="runtime"; Expression = { if ($_.CurrentTime) { [SummaryInfo]::Elapsed($_.CurrentTime.Elapsed) } else { "stopped" } } }
		@{ Label="uptime"; Expression = { [SummaryInfo]::Elapsed($Summary.TotalTime.Elapsed) } }
		@{ Label="boottime"; Expression = { [SummaryInfo]::Elapsed($Summary.UpTime()) } }
		@{ Label="bench"; Expression = { $_.Action -eq [eAction]::Benchmark } }
		@{ Label="ftime"; Expression = { $Summary.FeeTime.IsRunning } }
		@{ Label="profit"; Expression = { $cur = $_; $miner = $AllMiners | Where-Object { $_.Miner.GetUniqueKey() -eq $cur.Miner.GetUniqueKey() -and $_.Miner.Type -eq $cur.Miner.Type } | Select-Object -First 1; if ($miner) { [decimal]::Round($miner.Profit, 8) } else { $null } } }
		@{ Label="ver"; Expression = { [Config]::Version } }
		@{ Label="psver"; Expression = { [string]$PSVersionTable.PSVersion } }
		@{ Label="devices"; Expression = { Get-DevicesForApi ($_.Miner.Type) } }
	))

	$ActiveMinersFormatTable
}

function Get-JsonForMonitoring {
	$list = [Collections.ArrayList]::new()
	$active = $ActiveMiners.Values | Where-Object { $_.State -eq [eState]::Running }
	if ($active) { $list.AddRange(@($active)) }
	[Config]::ActiveTypes | ForEach-Object {
		$type = $_
		if (!($list | Where-Object { $_.Miner.Type -eq $type } | Select-Object -First 1) -and
			($AllMiners | Where-Object { $_.Miner.Type -eq $type } | Select-Object -First 1)) {
			$list.AddRange(@([PSCustomObject]@{ Miner = @{ Type = "$type" }}))
		}
	}
	$list | Select-Object (Get-FormatActiveMinersOnline) | ConvertTo-Json -Compress
	Remove-Variable active, list
}