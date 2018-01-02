. .\Code\PoolInfo.ps1

[Collections.Generic.Dictionary[string, PoolInfo]] $PoolCache = [Collections.Generic.Dictionary[string, PoolInfo]]::new()

function Get-PoolInfo([Parameter(Mandatory)][string] $folder) {
	<#  # old code
		$AllPools = Get-ChildItem "Pools" | Where-Object Extension -eq ".ps1" | ForEach-Object {
			Invoke-Expression "Pools\$($_.Name)"
		} | Where-Object { $_ -is [PoolInfo] -and $_.Profit -gt 0 }

		# find more profitable algo from all pools
		$AllPools = $AllPools | Select-Object Algorithm -Unique | ForEach-Object {
			$max = 0; $each = $null
			$AllPools | Where-Object Algorithm -eq $_.Algorithm | ForEach-Object {
				if ($max -lt $_.Profit) { $max = $_.Profit; $each = $_ }
			}
			if ($max -gt 0) { $each }
			Remove-Variable max
		}
	#>

	# get PoolInfo from all pools
	Get-ChildItem $folder | Where-Object Extension -eq ".ps1" | ForEach-Object {
		[PoolInfo] $pool = Invoke-Expression "$folder\$($_.Name)"
		if ($pool) {
			if ($PoolCache.ContainsKey($pool.Name)) {
				if ($pool.HasAnswer -or $pool.Enabled -ne $PoolCache[$pool.Name].Enabled) {
					$PoolCache[$pool.Name] = $pool
				}
				else {
					$PoolCache[$pool.Name].Algorithms | ForEach-Object {
						$_.Profit = $_.Profit * 0.99
					}
				}
			}
			else {
				$PoolCache.Add($pool.Name, $pool)
			}
		}
		Remove-Variable pool
	}

	# disble pools if not answer more then timeout
	$PoolCache.Values | Where-Object { $_.Enabled -and ([datetime]::Now - $_.AnswerTime).TotalMinutes -gt $Config.NoHashTimeout } | ForEach-Object {
		$_.Enabled = $false
	}

	# find more profitable algo from all pools
	$pools = [System.Collections.Generic.Dictionary[string, PoolAlgorithmInfo]]::new()
	$PoolCache.Values | Where-Object { $_.Enabled } | ForEach-Object {
		$_.Algorithms | ForEach-Object {
			if ($pools.ContainsKey($_.Algorithm)) {
				if ($pools[$_.Algorithm].Profit -lt $_.Profit) {
					$pools[$_.Algorithm] = $_
				}
			}
			else {
				$pools.Add($_.Algorithm, $_)
			}
		}
	}
	$pools.Values | ForEach-Object {
		$_
	}
}

function Out-PoolInfo {
	$PoolCache.Values | Format-Table @{ Label="Pool"; Expression = { $_.Name } },
		@{ Label="Enabled"; Expression = { $_.Enabled } },
		@{ Label="Answer ago"; Expression = { $ts = [datetime]::Now - $_.AnswerTime; if ($ts.TotalMinutes -gt $Config.NoHashTimeout) { "Unknown" } else { [SummaryInfo]::Elapsed($ts) } }; Alignment="Right" },
		@{ Label="Average Profit"; Expression = { $_.AverageProfit }; Alignment="Center" } |
		Out-Host
}

function Out-PoolBalance {
	$values = $PoolCache.Values | Where-Object { ([datetime]::Now - $_.AnswerTime).TotalMinutes -le $Config.NoHashTimeout } |
		Select-Object Name, @{ Name = "Confirmed"; Expression = { $_.Balance.Value } },
		@{ Name = "Unconfirmed"; Expression = { $_.Balance.Additional } },
		@{ Name = "Balance"; Expression = { $_.Balance.Value + $_.Balance.Additional } }
	$sum = $values | Measure-Object "Confirmed", "Unconfirmed", "Balance" -Sum
	$values += [PSCustomObject]@{ Name = "Total:"; Confirmed = $sum[0].Sum; Unconfirmed = $sum[1].Sum; Balance = $sum[2].Sum }
	$values |
		Format-Table @{ Label="Pool"; Expression = { $_.Name } },
			@{ Label="Confirmed, BTC"; Expression = { $_.Confirmed }; FormatString = "N8" },
			@{ Label="Unconfirmed, BTC"; Expression = { $_.Unconfirmed }; FormatString = "N8" },
			@{ Label="Balance, BTC"; Expression = { $_.Balance }; FormatString = "N8" } |
		Out-Host
	Remove-Variable sum, values
}