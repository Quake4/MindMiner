function Get-FormatMiners {
	$AllMinersFormatTable = [Collections.ArrayList]::new()

	$AllMinersFormatTable.AddRange(@(
		@{ Label="Miner"; Expression = { $_.Miner.Name } }
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