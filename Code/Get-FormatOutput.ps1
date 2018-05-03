function Get-FormatMiners {
	
	$AllMinersFormatTable = [Collections.ArrayList]::new()

	$AllMinersFormatTable.AddRange(@(
		@{ Label="Miner"; Expression = {
			$uniq =  $_.Miner.GetUniqueKey()
			$str = if ($_.SwitchingResistance) { "%" } else { [string]::Empty }
			($ActiveMiners.Values | Where-Object { $_.State -ne [eState]::Stopped } | ForEach-Object {
				if ($_.Miner.GetUniqueKey() -eq $uniq) {
					if ($_.State -eq [eState]::Running) { $str = "+" }
					elseif ($_.State -eq [eState]::NoHash) { $str = "-" }
					elseif ($_.State -eq [eState]::Failed) { $str = "!" }
					else { $str = [string]::Empty } } })
			$str + $_.Miner.Name } }
		@{ Label="Algorithm"; Expression = { "$($_.Miner.Algorithm)$(if (![string]::IsNullOrWhiteSpace($_.Miner.DualAlgorithm)) { "+$($_.Miner.DualAlgorithm)" } else { [string]::Empty })" } }
		@{ Label="Speed, H/s"; Expression = { if ($_.Speed -eq 0) { if ($global:HasConfirm -eq $true) { "Benchmarking" } else { "Need bench" } } else { [MultipleUnit]::ToString($_.Speed) } }; Alignment="Right" }
	))

	# hack
	for ($i = 0; $i -lt $Rates.Count; $i++) {
		if ($i -eq 0) {
			$AllMinersFormatTable.AddRange(@(
				@{ Label="$($Rates[0][0])/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * $Rates[0][1] } }; FormatString = "N$($Config.Currencies[0][1])" }
			))	
		}
		elseif ($i -eq 1) {
			$AllMinersFormatTable.AddRange(@(
				@{ Label="$($Rates[1][0])/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * $Rates[1][1] } }; FormatString = "N$($Config.Currencies[1][1])" }
			))	
		}
		elseif ($i -eq 2) {
			$AllMinersFormatTable.AddRange(@(
				@{ Label="$($Rates[2][0])/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * $Rates[2][1] } }; FormatString = "N$($Config.Currencies[2][1])" }
			))	
		}
	}

	$AllMinersFormatTable.AddRange(@(
		# @{ Label="mBTC/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * 1000 } }; FormatString = "N5" }
		@{ Label="BTC/GH/Day"; Expression = { $_.Price * 1000000000 }; FormatString = "N8" }
		@{ Label="Pool"; Expression = { $_.Miner.Pool } }
		@{ Label="ExtraArgs"; Expression = { $_.Miner.ExtraArgs } }
	))
	
	$AllMinersFormatTable
}

function Get-FormatActiveMiners {
	$ActiveMinersFormatTable = [Collections.ArrayList]::new()

	$ActiveMinersFormatTable.AddRange(@(
		@{ Label="Type"; Expression = { $_.Miner.Type } }
		@{ Label="Pool"; Expression = { $_.Miner.Pool } }
		@{ Label="Algorithm"; Expression = { $_.Miner.Algorithm } }
		@{ Label="Speed, H/s"; Expression = { $speed = $_.GetSpeed(); if ($speed -eq 0) { "Unknown" } else { [MultipleUnit]::ToString($speed) } }; Alignment="Right"; }
		@{ Label="Run Time"; Expression = { [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) }; Alignment = "Right" }
		@{ Label="Run"; Expression = { if ($_.Run -eq 1) { "Once" } else { $_.Run } } }
		@{ Label="Command"; Expression = { $_.Miner.GetCommandLine() } }
	))

	$ActiveMinersFormatTable
}

function Get-FormatActiveMinersWeb {
	$ActiveMinersFormatTable = [Collections.ArrayList]::new()

	$ActiveMinersFormatTable.AddRange(@(
		@{ Label="Type"; Expression = { $_.Miner.Type } }
		@{ Label="Pool"; Expression = { $_.Miner.Pool } }
		@{ Label="Algorithm"; Expression = { $_.Miner.Algorithm } }
		@{ Label="Speed, H/s"; Expression = { $speed = $_.GetSpeed(); if ($speed -eq 0) { "Unknown" } else { [MultipleUnit]::ToString($speed) } } }
		@{ Label="Run Time"; Expression = { [SummaryInfo]::Elapsed($_.TotalTime.Elapsed) } }
		@{ Label="Run"; Expression = { if ($_.Run -eq 1) { "Once" } else { $_.Run } } }
		@{ Label="Command"; Expression = { $_.Miner.GetCommandLine() } }
	))

	$ActiveMinersFormatTable
}