<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Out-DeviceInfo ([bool] $OnlyTotal) {
	$valuesweb = [Collections.ArrayList]::new()
	$valuesapi = [Collections.ArrayList]::new()

	[bool] $has = $false
	[Config]::ActiveTypes | ForEach-Object {
		$type = [eMinerType]::nVidia # $_
		if ($Devices.$type -and $Devices.$type.Length -gt 0) {
			if ($OnlyTotal) {
				$measure = $Devices.$type | Measure-Object "Clock", "ClockMem", "Load", "LoadMem", "Temperature", "Power", "PowerLimit" -Min -Max
				$str = "$type`: "
				if ($measure[0].Minimum -eq $measure[0].Maximum) { $str += "$($measure[0].Minimum)/" } else { $str += "$($measure[0].Minimum)-$($measure[0].Maximum)/" }
				if ($measure[1].Minimum -eq $measure[1].Maximum) { $str += "$($measure[1].Minimum) Mhz, " } else { $str += "$($measure[1].Minimum)-$($measure[1].Maximum) Mhz, " }
				if ($measure[2].Minimum -eq $measure[2].Maximum) { $str += "$($measure[2].Minimum)/" } else { $str += "$($measure[2].Minimum)-$($measure[2].Maximum)/" }
				if ($measure[3].Minimum -eq $measure[3].Maximum) { $str += "$($measure[3].Minimum) %, " } else { $str += "$($measure[3].Minimum)-$($measure[3].Maximum) %, " }
				if ($measure[4].Minimum -eq $measure[4].Maximum) { $str += "$($measure[4].Minimum) C, " } else { $str += "$($measure[4].Minimum)-$($measure[4].Maximum) C, " }
				if ($measure[5].Minimum -eq $measure[5].Maximum) { $str += "$($measure[5].Minimum) W, " } else { $str += "$($measure[5].Minimum)-$($measure[5].Maximum) W, " }
				if ($measure[6].Minimum -eq $measure[6].Maximum) { $str += "$($measure[6].Minimum) %" } else { $str += "$($measure[6].Minimum)-$($measure[6].Maximum) %" }
				Write-Host $str
				Remove-Variable measure
				$has = $true
			}
			else {
				Write-Host "   Type: $type"
				Write-Host
				$columns = [Collections.ArrayList]::new()
				$columns.AddRange(@(
					@{ Label="GPU"; Expression = { $_.Name } }
					@{ Label="Clock, MHz"; Expression = { "$($_.Clock)/$($_.ClockMem)" }; Alignment = "Center" }
					@{ Label="Load, %"; Expression = { "$($_.Load)/$($_.LoadMem)" }; Alignment = "Center" }
					@{ Label="Temp, C"; Expression = { $_.Temperature }; Alignment = "Right" }
					@{ Label="Power, W"; Expression = { $_.Power }; Alignment = "Right" }
					@{ Label="PL, %"; Expression = { $_.PowerLimit }; Alignment = "Right" }
				))
				Out-Table ($Devices.$type | Format-Table $columns)
				Remove-Variable columns
			}
		}
	}
	if ($has) { Write-Host }

	return;

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
}