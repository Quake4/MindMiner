<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\PoolInfo.ps1

[Collections.Generic.Dictionary[string, PoolInfo]] $PoolCache = [Collections.Generic.Dictionary[string, PoolInfo]]::new()

function Get-PoolInfo([Parameter(Mandatory)][string] $folder) {
	# get PoolInfo from all pools
	Get-ChildItem $folder | Where-Object Extension -eq ".ps1" | ForEach-Object {
		[string] $name = $_.Name.Replace(".ps1", [string]::Empty)
		Invoke-Expression "$folder\$($_.Name)" | ForEach-Object {
			[PoolInfo] $pool = $_ -as [PoolInfo]
			if ($pool) {
				$pool.Name = $name
				if ($PoolCache.ContainsKey($pool.Name)) {
					$poolcached = $PoolCache[$pool.Name]
					if ($pool.HasAnswer -or $pool.Enabled -ne $poolcached.Enabled -or $pool.AverageProfit -ne $poolcached.AverageProfit) {
						$PoolCache[$pool.Name] = $pool
					}
					elseif (!$pool.HasAnswer -and $poolcached.Enabled) {
						$PoolCache[$pool.Name].Algorithms | ForEach-Object {
							$_.Profit = $_.Profit * 0.995
						}
					}
					Remove-Variable poolcached
				}
				else {
					$PoolCache.Add($pool.Name, $pool)
				}
			}
			elseif ($PoolCache.ContainsKey($name)) {
				$PoolCache.Remove($name)
			}
			Remove-Variable pool
		}
		Remove-Variable name
	}

	# find more profitable algo from all pools
	$pools = [Collections.Generic.Dictionary[string, PoolAlgorithmInfo]]::new()
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

	$global:API.Pools = $pools
	$wallets = $Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
	$pools.Values | ForEach-Object {
		$userpass = "$($_.User)$($_.Password)"
		$userpass = $userpass.Replace([Config]::WorkerNamePlaceholder, [string]::Empty)
		if (![string]::IsNullOrEmpty($Config.Login)) {
			$userpass = $userpass.Replace([Config]::LoginPlaceholder + ".", [string]::Empty + ".")
		}
		$wallets | ForEach-Object { $userpass = $userpass.Replace((([Config]::WalletPlaceholder -f "$_")), [string]::Empty) }
		if (!$userpass.Contains([Config]::Placeholder)) {
			$_
		}
	}
}

function Out-PoolInfo {
	$PoolCache.Values | Format-Table @{ Label="Pool"; Expression = { $_.Name } },
		@{ Label="Enabled"; Expression = { $_.Enabled } },
		@{ Label="Answer ago"; Expression = { $ts = [datetime]::Now - $_.AnswerTime; if ($ts.TotalMinutes -gt $Config.NoHashTimeout) { if ($_.Enabled) { "Offline" } else { "Unknown" } } else { [SummaryInfo]::Elapsed($ts) } }; Alignment="Right" },
		@{ Label=if ([Config]::UseApiProxy -eq $true) { "Proxy" } else { "Average Profit" }; Expression = { if ([Config]::UseApiProxy -eq $false -and ($Config.Switching -as [eSwitching]) -eq [eSwitching]::Normal) { $_.AverageProfit } else { "None" } }; Alignment="Center" } |
		Out-String -Stream | Where-Object { $_ -ne [string]::Empty } | Out-Host
}

function Out-PoolBalance ([bool] $OnlyTotal) {
	$valuesweb = [Collections.ArrayList]::new()
	$wallets = (@($Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) + 
		($PoolCache.Values | ForEach-Object { $_.Balance.Keys } | % { $_ })) | Select-Object -Unique;
	#if (!$OnlyTotal) {
		$wallets <#| Where-Object { $_ -ne $Config.Currencies[0][0] }#> | ForEach-Object {
			$wallet = "$_"
			$values = $PoolCache.Values | Where-Object { $_.Balance.ContainsKey($wallet) -and ([datetime]::Now - $_.AnswerTime).TotalMinutes -le $Config.NoHashTimeout } |
				Select-Object Name, @{ Name = "Confirmed"; Expression = { $_.Balance[$wallet].Value } },
				@{ Name = "Unconfirmed"; Expression = { $_.Balance[$wallet].Additional } },
				@{ Name = "Balance"; Expression = { $_.Balance[$wallet].Value + $_.Balance[$wallet].Additional } }
			if ($values) {
				if ($values.Length -gt 0) {
					$sum = $values | Measure-Object "Confirmed", "Unconfirmed", "Balance" -Sum
					if ($OnlyTotal) { $values.Clear() }
					$values += [PSCustomObject]@{ Name = "Total:"; Confirmed = $sum[0].Sum; Unconfirmed = $sum[1].Sum; Balance = $sum[2].Sum }
					Remove-Variable sum
				}
				$columns = [Collections.ArrayList]::new()
				$columns.AddRange(@(
					@{ Label="Pool"; Expression = { $_.Name } }
					@{ Label="Confirmed, $wallet"; Expression = { $_.Confirmed }; FormatString = "N8" }
					@{ Label="Unconfirmed, $wallet"; Expression = { $_.Unconfirmed }; FormatString = "N8" }
					@{ Label="Balance, $wallet"; Expression = { $_.Balance }; FormatString = "N8" }
				))
				# hack
				for ($i = 0; $i -lt $Rates[$wallet].Count; $i++) {
					if ($i -eq 0 -and $wallet -ne $Rates[$wallet][0][0]) {
						$columns.AddRange(@(
							@{ Label="Balance, $($Rates[$wallet][0][0])"; Expression = { $_.Balance * $Rates[$wallet][0][1] }; FormatString = "N$($Config.Currencies[0][1])" }
						))	
					}
					elseif ($i -eq 1) {
						$columns.AddRange(@(
							@{ Label="Balance, $($Rates[$wallet][1][0])"; Expression = { $_.Balance * $Rates[$wallet][1][1] }; FormatString = "N$($Config.Currencies[1][1])" }
						))	
					}
					elseif ($i -eq 2) {
						$columns.AddRange(@(
							@{ Label="Balance, $($Rates[$wallet][2][0])"; Expression = { $_.Balance * $Rates[$wallet][2][1] }; FormatString = "N$($Config.Currencies[2][1])" }
						))	
					}
				}

				if ($global:API.Running) {
					$columnsweb = [Collections.ArrayList]::new()
					$columnsweb.AddRange(@(
						@{ Label="Pool"; Expression = { $_.Name } }
						@{ Label="Confirmed, $wallet"; Expression = { "{0:N8}" -f $_.Confirmed } }
						@{ Label="Unconfirmed, $wallet"; Expression = { "{0:N8}" -f $_.Unconfirmed } }
						@{ Label="Balance, $wallet"; Expression = { "{0:N8}" -f $_.Balance } }
					))
					# hack
					for ($i = 0; $i -lt $Rates[$wallet].Count; $i++) {
						if ($i -eq 0 -and $wallet -ne $Rates[$wallet][0][0]) {
							$columnsweb.AddRange(@(
								@{ Label="Balance, $($Rates[$wallet][0][0])"; Expression = { "{0:N$($Config.Currencies[0][1])}" -f ($_.Balance * $Rates[$wallet][0][1]) } }
							))	
						}
						elseif ($i -eq 1) {
							$columnsweb.AddRange(@(
								@{ Label="Balance, $($Rates[$wallet][1][0])"; Expression = { "{0:N$($Config.Currencies[1][1])}" -f ($_.Balance * $Rates[$wallet][1][1]) } }
							))	
						}
						elseif ($i -eq 2) {
							$columnsweb.AddRange(@(
								@{ Label="Balance, $($Rates[$wallet][2][0])"; Expression = { "{0:N$($Config.Currencies[2][1])}" -f ($_.Balance * $Rates[$wallet][2][1]) } }
							))	
						}
					}
					$valuesweb.AddRange(@(($values | Select-Object $columnsweb | ConvertTo-Html -Fragment)))
					Remove-Variable columnsweb
				}

				$values | Format-Table $columns | Out-String -Stream | Where-Object { $_ -ne [string]::Empty } | Out-Host
				Write-Host
				Remove-Variable columns, values, wallet
			}
		}
	#}
<#
	$values = $wallets | ForEach-Object {
		$wallet = "$_"
		$PoolCache.Values | Where-Object { $_.Balance.ContainsKey($wallet) -and ([datetime]::Now - $_.AnswerTime).TotalMinutes -le $Config.NoHashTimeout } |
			Select-Object Name, @{ Name = "Confirmed"; Expression = { $_.Balance[$wallet].Value * $Rates[$wallet][0][1] } },
			@{ Name = "Unconfirmed"; Expression = { $_.Balance[$wallet].Additional * $Rates[$wallet][0][1] } },
			@{ Name = "Balance"; Expression = { ($_.Balance[$wallet].Value + $_.Balance[$wallet].Additional) * $Rates[$wallet][0][1] } }
	}

	$values = $values | Group-Object -Property Name | ForEach-Object {
		$sum = $_.Group | Measure-Object "Confirmed", "Unconfirmed", "Balance" -Sum
		[PSCustomObject]@{ Name = "$($_.Name)"; Confirmed = $sum[0].Sum; Unconfirmed = $sum[1].Sum; Balance = $sum[2].Sum }
		Remove-Variable sum
	}

	if ($values) {
		if ($values.Length -gt 0) {
			$sum = $values | Measure-Object "Confirmed", "Unconfirmed", "Balance" -Sum
			if ($OnlyTotal) { $values.Clear() }
			$values += [PSCustomObject]@{ Name = "Total:"; Confirmed = $sum[0].Sum; Unconfirmed = $sum[1].Sum; Balance = $sum[2].Sum }
			Remove-Variable sum
		}

		$wallet = $Config.Currencies[0][0]
		$columns = [Collections.ArrayList]::new()
		$columns.AddRange(@(
			@{ Label="Pool"; Expression = { $_.Name } }
			@{ Label="Confirmed, $($Rates[$wallet][0][0])"; Expression = { $_.Confirmed }; FormatString = "N$($Config.Currencies[0][1])" }
			@{ Label="Unconfirmed, $($Rates[$wallet][0][0])"; Expression = { $_.Unconfirmed  }; FormatString = "N$($Config.Currencies[0][1])" }
			@{ Label="Balance, $($Rates[$wallet][0][0])"; Expression = { $_.Balance }; FormatString = "N$($Config.Currencies[0][1])" }
		))
		# hack
		for ($i = 0; $i -lt $Rates[$wallet].Count; $i++) {
			if ($i -eq 1) {
				$columns.AddRange(@(
					@{ Label="Balance, $($Rates[$wallet][1][0])"; Expression = { $_.Balance * $Rates[$wallet][1][1] }; FormatString = "N$($Config.Currencies[1][1])" }
				))	
			}
			elseif ($i -eq 2) {
				$columns.AddRange(@(
					@{ Label="Balance, $($Rates[$wallet][2][0])"; Expression = { $_.Balance * $Rates[$wallet][2][1] }; FormatString = "N$($Config.Currencies[2][1])" }
				))	
			}
		}

		if ($global:API.Running) {
			$columnsweb = [Collections.ArrayList]::new()
			$columnsweb.AddRange(@(
				@{ Label="Pool"; Expression = { $_.Name } }
				@{ Label="Confirmed, $($Rates[$wallet][0][0])"; Expression = { "{0:N$($Config.Currencies[0][1])}" -f $_.Confirmed } }
				@{ Label="Unconfirmed, $($Rates[$wallet][0][0])"; Expression = { "{0:N$($Config.Currencies[0][1])}" -f $_.Unconfirmed } }
				@{ Label="Balance, $($Rates[$wallet][0][0])"; Expression = { "{0:N$($Config.Currencies[0][1])}" -f $_.Balance } }
			))
			# hack
			for ($i = 0; $i -lt $Rates[$wallet].Count; $i++) {
				if ($i -eq 1) {
					$columnsweb.AddRange(@(
						@{ Label="Balance, $($Rates[$wallet][1][0])"; Expression = { "{0:N$($Config.Currencies[1][1])}" -f ($_.Balance * $Rates[$wallet][1][1]) } }
					))	
				}
				elseif ($i -eq 2) {
					$columnsweb.AddRange(@(
						@{ Label="Balance, $($Rates[$wallet][2][0])"; Expression = { "{0:N$($Config.Currencies[2][1])}" -f ($_.Balance * $Rates[$wallet][2][1]) } }
					))	
				}
			}
			$valuesweb.AddRange(@(($values | Select-Object $columnsweb | ConvertTo-Html -Fragment)))
			Remove-Variable columnsweb
		}

		$values | Format-Table $columns | Out-Host
		Remove-Variable columns, values, wallet
#>
		if ($global:API.Running) {
			$global:API.Balance = $valuesweb
		}
#	}
	Remove-Variable valuesweb

	if ($Config.ShowExchangeRate) {
		$wallets = $wallets | Where-Object { "$_" -ne "NiceHash" }
		$columns = [Collections.ArrayList]::new()
		$columns.AddRange(@(
			@{ Label="Coin"; Expression = { $_.Name } }
		))
		$wallet = $Config.Currencies[0][0];
		for ($i = 0; $i -lt $Rates[$wallet].Count; $i++) {
			if ($i -eq 0 -and !($wallet -eq $Rates[$wallet][0][0] -and $wallet -eq "$wallets")) {
				$columns.AddRange(@(
					@{ Label="$($Rates[$wallet][0][0])"; Expression = { $Rates[$_.Name][0][1] }; FormatString = "N$($Config.Currencies[0][1])" }
				))	
			}
			elseif ($i -eq 1 -and !($wallet -eq $Rates[$wallet][1][0] -and $wallet -eq "$wallets")) {
				$columns.AddRange(@(
					@{ Label="$($Rates[$wallet][1][0])"; Expression = { $Rates[$_.Name][1][1] }; FormatString = "N$($Config.Currencies[1][1])" }
				))	
			}
			elseif ($i -eq 2 -and !($wallet -eq $Rates[$wallet][2][0] -and $wallet -eq "$wallets")) {
				$columns.AddRange(@(
					@{ Label="$($Rates[$wallet][2][0])"; Expression = { $Rates[$_.Name][2][1] }; FormatString = "N$($Config.Currencies[2][1])" }
				))	
			}
		}
		$wallets | Select-Object @{ Name = "Name"; Expression = { "$_" } } | Format-Table $columns | Out-String -Stream | Where-Object { $_ -ne [string]::Empty } | Out-Host
		Write-Host
		Remove-Variable columns
	}
}