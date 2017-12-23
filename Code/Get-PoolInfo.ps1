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