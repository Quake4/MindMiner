<#
MindMiner  Copyright (C) 2018-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-RateInfo {
	Write-Host "Get exchange rates ..." -ForegroundColor Green	
	$result = [Collections.Generic.Dictionary[string, object]]::new()

	$conins = [Collections.ArrayList]::new()
	$conins.AddRange(@("BTC", "DASH", "LTC", "ETH"));
	if ($Config.Wallet) {
		$Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object { "$_" -notmatch "nicehash" } |
			ForEach-Object { if ($conins -notcontains "$_") { $conins.AddRange(@("$_")) } }
	}
	if ($Config.LowerFloor) {
		$Config.LowerFloor | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			$Config.LowerFloor.$_ | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { if ($conins -notcontains "$_") { $conins.AddRange(@("$_")) } }
		}
	}
	$epcurr = Get-ElectricityPriceCurrency
	if ($epcurr) {
		if ($conins -notcontains "$epcurr") { $conins.AddRange(@("$epcurr")) }
	}

	$json = Get-Rest "https://min-api.cryptocompare.com/data/pricemulti?fsyms=$(Get-Join "," $conins)&tsyms=$(Get-Join "," ($Config.Currencies | ForEach-Object { $_[0] }))"

	if ($json -and $json.Response -notmatch "Error") {
		($json | ConvertTo-Json -Compress).Split(@("},", "}}"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
			$signs = $_.Split(@(":{", "{"), [StringSplitOptions]::RemoveEmptyEntries)
			$coins = [Collections.Generic.List[object]]::new()
			$signs[1].Split(@(","), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
				$each = "$_".Split(@(":", "`""), [StringSplitOptions]::RemoveEmptyEntries)
				$coins.Add(@("$($each[0])"; [MultipleUnit]::ToValueInvariant($each[1], [string]::Empty)))
			}
			$result.Add($signs[0].Replace("`"", [string]::Empty), $coins)
		}
		$conins | ForEach-Object {
			if (!$result.ContainsKey($_)) {
				$json = $null
				$json = Get-Rest "https://min-api.cryptocompare.com/data/price?fsym=$_&tsyms=$(Get-Join "," ($Config.Currencies | ForEach-Object { $_[0] }))"
				if ($json -and $json.Response -notmatch "Error") {
					$coins = [Collections.Generic.List[object]]::new()
					$Config.Currencies | ForEach-Object {
						$coins.Add(@("$($_[0])", [decimal]$json."$($_[0])"))
					}
					$result.Add($_, $coins)
				}
			}
		}
	}
	else {
		$conins | ForEach-Object {
			$wallet = "$_"
			# only BTC if show balance is off
			if (!$result.ContainsKey($wallet) -and ($wallet.Contains("BTC") -or $Config.ShowBalance -eq $true)) {
				$json = Get-Rest "https://api.coinbase.com/v2/exchange-rates?currency=$wallet"
				if ($json) {
					$values = [Collections.Generic.List[object]]::new()
					$Config.Currencies | ForEach-Object {
						if ([string]::Equals($_[0], $wallet, [StringComparison]::InvariantCultureIgnoreCase)) {
							$values.Add(@($wallet, [decimal]1))
						}
						elseif ([string]::Equals($_[0], "m$wallet", [StringComparison]::InvariantCultureIgnoreCase)) {
							$values.Add(@("m$wallet", [decimal]1000))
						}
						elseif ($json.data.rates."$($_[0])") {
							$values.Add(@($_[0], [decimal]$json.data.rates."$($_[0])"))
						}
					}
					$result.Add($wallet, $values)
				}
			}
		}
	}
	,$result
}