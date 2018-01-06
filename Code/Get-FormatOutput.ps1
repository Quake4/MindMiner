function Get-FormatMiners {

		# Format-Table @{ Label="Miner"; Expression = {
		# 		$uniq =  $_.Miner.GetUniqueKey()
		# 		$str = [string]::Empty
		# 		($ActiveMiners.Values | Where-Object { $_.State -ne [eState]::Stopped } | ForEach-Object {
		# 			if ($_.Miner.GetUniqueKey() -eq $uniq) {
		# 				if ($_.State -eq [eState]::Running) { $str = "*" } elseif ($_.State -eq [eState]::NoHash) { $str = "-" } elseif ($_.State -eq [eState]::Failed) { $str = "!" } } })
		# 		$str + $_.Miner.Name } },
		# 	@{ Label="Algorithm"; Expression = { $_.Miner.Algorithm } },
		# 	@{ Label="Speed, H/s"; Expression = { if ($_.Speed -eq 0) { "Testing" } else { [MultipleUnit]::ToString($_.Speed) } }; Alignment="Right" },
		# 	@{ Label="mBTC/Day"; Expression = { if ($_.Speed -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * 1000 } }; FormatString = "N5" },
		# 	@{ Label="BTC/GH/Day"; Expression = { $_.Price * 1000000000 }; FormatString = "N8" },
		# 	@{ Label="Pool"; Expression = { $_.Miner.Pool } },
		# 	@{ Label="ExtraArgs"; Expression = { $_.Miner.ExtraArgs } } -GroupBy @{ Label="Type"; Expression = { $_.Miner.Type } } | Out-Host
	
	$AllMinersFormatTable = [Collections.ArrayList]::new()

	$AllMinersFormatTable.AddRange(@(
		@{ Label="Miner"; Expression = {
			$uniq =  $_.Miner.GetUniqueKey()
			$str = [string]::Empty
			($ActiveMiners.Values | Where-Object { $_.State -ne [eState]::Stopped } | ForEach-Object {
				if ($_.Miner.GetUniqueKey() -eq $uniq) {
					if ($_.State -eq [eState]::Running) { $str = "*" } elseif ($_.State -eq [eState]::NoHash) { $str = "-" } elseif ($_.State -eq [eState]::Failed) { $str = "!" } } })
			$str + $_.Miner.Name } }
		@{ Label="Algorithm"; Expression = { $_.Miner.Algorithm } }
		@{ Label="Speed, H/s"; Expression = { if ($_.Speed -eq 0) { "Testing" } else { [MultipleUnit]::ToString($_.Speed) } }; Alignment="Right" }
	))

	ForEach($item in $Rates.GetEnumerator()) {
		$AllMinersFormatTable.AddRange(@(
			#@{ Label="$($item.Key)/Day"; Expression = { if ($_.Profit -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * [decimal]"$($item.Value)" } }; FormatString = "N5" }
			@{ Label="$($item.Key)/Day"; Expression = "$($_.Profit )"; }
		))
	}

	# for ($i = 0; $i -lt $Rates.Count; $i++) {
	# 	# $each = $Rates[i]
	# 	$AllMinersFormatTable.Add(
	# 		@{ Label="$_/Day"; Expression = { if ($_.Profit -eq 0) { "$($_.Miner.BenchmarkSeconds) sec" } else { $_.Profit * $Rates.$_ } }; FormatString = "N5" }
	# 	)
	# }

	$AllMinersFormatTable.AddRange(@(
		@{ Label="BTC/GH/Day"; Expression = { $_.Price * 1000000000 }; FormatString = "N8" }
		@{ Label="Pool"; Expression = { $_.Miner.Pool } }
		@{ Label="ExtraArgs"; Expression = { $_.Miner.ExtraArgs } }
	))
	
	$AllMinersFormatTable
}