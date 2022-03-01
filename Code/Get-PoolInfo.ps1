<#
MindMiner  Copyright (C) 2017-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\PoolInfo.ps1

[Collections.Generic.Dictionary[string, PoolInfo]] $PoolCache = [Collections.Generic.Dictionary[string, PoolInfo]]::new()
[Collections.Generic.Dictionary[string, decimal]] $PoolProfitCache = [Collections.Generic.Dictionary[string, decimal]]::new()

function Get-PoolInfo([Parameter(Mandatory)][string] $folder) {
	# get PoolInfo from all pools
	Get-ChildItem $folder | Where-Object Extension -eq ".ps1" | ForEach-Object {
		[string] $name = $_.Name.Replace(".ps1", [string]::Empty)
		if ([string]::IsNullOrWhiteSpace($global:MRRFile) -and $name -match [Config]::MRRFile) {
			$global:MRRFile = "$folder\$($_.Name)"
		}
		Invoke-Expression "$folder\$($_.Name)" | ForEach-Object {
			[PoolInfo] $pool = $_ -as [PoolInfo]
			if ($pool) {
				$pool.Name = $name
				if ($PoolCache.ContainsKey($name)) {
					$poolcached = $PoolCache[$name]
					if ($pool.HasAnswer -or $pool.Enabled -ne $poolcached.Enabled -or $pool.AverageProfit -ne $poolcached.AverageProfit) {
						$PoolCache[$name] = $pool
					}
					elseif (!$pool.HasAnswer -and $poolcached.Enabled -and $name -notmatch [Config]::MRRFile) {
						$PoolCache[$name].Algorithms | ForEach-Object {
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
	$apipools = [Collections.Generic.Dictionary[string, PoolAlgorithmInfo]]::new()
	$PoolProfitCache.Clear()
	$PoolCache.Values | Where-Object { $_.Enabled } | ForEach-Object {
		$_.Algorithms | ForEach-Object {
			if ($pools.ContainsKey($_.Algorithm)) {
				if ($pools[$_.Algorithm].Priority -lt $_.Priority -or ($pools[$_.Algorithm].Priority -eq $_.Priority -and $pools[$_.Algorithm].Profit -lt $_.Profit)) {
					[decimal] $prft = 0
					if ($_.Priority -ne [Priority]::None -and $_.Priority -ne [Priority]::Unique) {
						$prft = [math]::Max($_.Profit, $pools[$_.Algorithm].Extra.bestprofit)
					}
					if ($_.Extra) { $_.Extra.bestprofit = $prft } else { $_.Extra = @{ bestprofit = $prft } }
					$pools[$_.Algorithm] = $_
					Remove-Variable prft
				}
				else {
					$alg = $pools[$_.Algorithm]
					if ($_.Priority -ne [Priority]::None -and $_.Priority -ne [Priority]::Unique) {
						$alg.Extra.bestprofit = [math]::Max($_.Profit, $alg.Extra.bestprofit)
					}
					Remove-Variable alg
				}
			}
			else {
				[decimal] $prft = 0
				if ($_.Priority -ne [Priority]::None -and $_.Priority -ne [Priority]::Unique) {
					$prft = $_.Profit
				}
				if ($_.Extra) { $_.Extra.bestprofit = $prft } else { $_.Extra = @{ bestprofit = $prft } }
				$pools.Add($_.Algorithm, $_)
				Remove-Variable prft
			}
			if ($_.Name -notmatch [Config]::MRRFile -and ($_.Priority -eq [Priority]::Normal -or $_.Priority -eq [Priority]::High -or $_.Priority -eq [Priority]::Solo)) {
				if ($apipools.ContainsKey($_.Algorithm)) {
					if ($apipools[$_.Algorithm].Priority -lt $_.Priority -or $apipools[$_.Algorithm].Profit -lt $_.Profit) {
						$apipools[$_.Algorithm] = $_
					}
				}
				else {
					$apipools.Add($_.Algorithm, $_)
				}
			}
			$key = $_.PoolKey()+$_.Algorithm
			if (!$PoolProfitCache.ContainsKey($key) -or $_.Profit -gt $PoolProfitCache[$key]) {
				$PoolProfitCache[$key] = $_.Profit
			}
		}
	}

	$global:API.Pools = $apipools
	
	if ($Config.Wallet) {
		$wallets = $Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
	}
	$pools.Values | ForEach-Object {
		$userpass = "$($_.User)$($_.Password)" -replace ([Config]::WorkerNamePlaceholder)
		if (![string]::IsNullOrEmpty($Config.Login)) {
			$userpass = $userpass.Replace([Config]::LoginPlaceholder + ".", [string]::Empty + ".")
		}
		$wallets | ForEach-Object { $userpass = $userpass.Replace((([Config]::WalletPlaceholder -f "$_")), [string]::Empty) }
		if (!$userpass.Contains([Config]::Placeholder)) {
			$_
		}
	}
}

function Get-PoolInfoEnabled([Parameter(Mandatory)][string] $poolkey, [string] $algoritrm, [string] $dualalgoritrm) {
	if ([string]::IsNullOrWhiteSpace($dualalgoritrm)) {
		$PoolProfitCache.ContainsKey("$poolkey$algoritrm")
	}
	else {
		$pk = $poolkey.Split("+")
		$PoolProfitCache.ContainsKey("$($pk[0])$algoritrm") -and $PoolProfitCache.ContainsKey("$($pk[1])$dualalgoritrm")
	}
}

function Get-PoolAlgorithmProfit([Parameter(Mandatory)][string] $poolkey, [string] $algoritrm, [string] $dualalgoritrm) {
	if ([string]::IsNullOrWhiteSpace($dualalgoritrm)) {
		$PoolProfitCache."$poolkey$algoritrm"
	}
	else {
		$pk = $poolkey.Split("+")
		@($PoolProfitCache."$($pk[0])$algoritrm", $PoolProfitCache."$($pk[1])$dualalgoritrm")
	}
}

function Out-PoolInfo {
	Out-Table ($PoolCache.Values | Format-Table @{ Label="Pool"; Expression = { $_.Name } },
		@{ Label="Enabled"; Expression = { $_.Enabled } },
		@{ Label="Answer ago"; Expression = { $ts = [datetime]::Now - $_.AnswerTime; if ($ts.TotalMinutes -gt $Config.NoHashTimeout) { if ($_.Enabled) { "Offline" } else { "Unknown" } } else { [SummaryInfo]::Elapsed($ts) } }; Alignment="Right" },
		@{ Label=if ([Config]::UseApiProxy -eq $true) { "Proxy" } else { "Average Profit" }; Expression = { if ([Config]::UseApiProxy -eq $false -and ($Config.Switching -as [eSwitching]) -eq [eSwitching]::Normal) { $_.AverageProfit } else { "None" } }; Alignment="Center" })
}

function Out-PoolBalance ([bool] $OnlyTotal) {
	$valuesweb = [Collections.ArrayList]::new()
	$valuesapi = [Collections.ArrayList]::new()
	if ($Config.Wallet) {
		$wallets = (@($Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name) + 
			($PoolCache.Values | ForEach-Object { $_.Balance.Keys } | % { $_ })) | Select-Object -Unique;
	}
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
					elseif ($i -eq 1 -and $wallet -ne $Rates[$wallet][1][0]) {
						$columns.AddRange(@(
							@{ Label="Balance, $($Rates[$wallet][1][0])"; Expression = { $_.Balance * $Rates[$wallet][1][1] }; FormatString = "N$($Config.Currencies[1][1])" }
						))	
					}
					elseif ($i -eq 2 -and $wallet -ne $Rates[$wallet][2][0]) {
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
						elseif ($i -eq 1 -and $wallet -ne $Rates[$wallet][1][0]) {
							$columnsweb.AddRange(@(
								@{ Label="Balance, $($Rates[$wallet][1][0])"; Expression = { "{0:N$($Config.Currencies[1][1])}" -f ($_.Balance * $Rates[$wallet][1][1]) } }
							))	
						}
						elseif ($i -eq 2 -and $wallet -ne $Rates[$wallet][2][0]) {
							$columnsweb.AddRange(@(
								@{ Label="Balance, $($Rates[$wallet][2][0])"; Expression = { "{0:N$($Config.Currencies[2][1])}" -f ($_.Balance * $Rates[$wallet][2][1]) } }
							))	
						}
					}
					$valuesweb.AddRange(@(($values | Select-Object $columnsweb | ConvertTo-Html -Fragment)))
					Remove-Variable columnsweb
					# api
					$columnsapi = [Collections.ArrayList]::new()
					$columnsapi.AddRange(@(
						@{ Label="pool"; Expression = { $_.Name } }
						@{ Label="wallet"; Expression = { $wallet } }
						@{ Label="confirmed"; Expression = { [decimal]::Round($_.Confirmed, 8) } }
						@{ Label="unconfirmed"; Expression = { [decimal]::Round($_.Unconfirmed, 8) } }
						@{ Label="balance"; Expression = { [decimal]::Round($_.Balance, 8) } }
					))
					$valuesapi.AddRange(@(($values | Select-Object $columnsapi)))
					Remove-Variable columnsapi
				}

				Out-Table ($values | Format-Table $columns)
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

		Out-Table ($values | Format-Table $columns)
		Remove-Variable columns, values, wallet
#>
		if ($global:API.Running) {
			$global:API.Balance = $valuesweb
			$global:API.Balances = $valuesapi
		}
#	}
	Remove-Variable valuesweb

	if ($Config.ShowExchangeRate) {
		$wallets = $wallets | Where-Object { "$_" -notmatch "nicehash" }
		$columns = [Collections.ArrayList]::new()
		$columns.AddRange(@(
			@{ Label="Coin"; Expression = { $_.Name } }
		))
		$wallet = $Config.Currencies[0][0];
		for ($i = 0; $i -lt $Rates[$wallet].Count; $i++) {
			if ($i -eq 0 -and !($wallet -eq $Rates[$wallet][0][0] -and $wallet -eq "$wallets")) {
				$columns.AddRange(@(
					@{ Label="$($Rates[$wallet][0][0])"; Expression = { $Rates[$_.Name][0][1] }; FormatString = "N$($Config.Currencies[0][1])"; Alignment="Right" }
				))	
			}
			elseif ($i -eq 1 -and !($wallet -eq $Rates[$wallet][1][0] -and $wallet -eq "$wallets")) {
				$columns.AddRange(@(
					@{ Label="$($Rates[$wallet][1][0])"; Expression = { $Rates[$_.Name][1][1] }; FormatString = "N$($Config.Currencies[1][1])"; Alignment="Right" }
				))	
			}
			elseif ($i -eq 2 -and !($wallet -eq $Rates[$wallet][2][0] -and $wallet -eq "$wallets")) {
				$columns.AddRange(@(
					@{ Label="$($Rates[$wallet][2][0])"; Expression = { $Rates[$_.Name][2][1] }; FormatString = "N$($Config.Currencies[2][1])"; Alignment="Right" }
				))	
			}
		}
		Out-Table ($wallets | Select-Object @{ Name = "Name"; Expression = { "$_" } } | Format-Table $columns)
		Remove-Variable columns
	}
}