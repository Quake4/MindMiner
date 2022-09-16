<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-RateInfo {
	Write-Host "Get exchange rates ..." -ForegroundColor Green	
	$result = [Collections.Generic.Dictionary[string, object]]::new()

	# not add - add returns index
	$coins = [Collections.ArrayList]::new()
	$coins.AddRange(@("BTC"))
	[Config]::MRRWallets | ForEach-Object {
		$coins.AddRange(@($_.ToUpper()))
	}
	if ($Config.Wallet) {
		$Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object { "$_" -notmatch "nicehash" } |
			ForEach-Object { if ($coins -notcontains "$_") { $coins.AddRange(@("$_")) } }
	}
	if ($Config.LowerFloor) {
		$Config.LowerFloor | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			$Config.LowerFloor.$_ | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { if ($coins -notcontains "$_") { $coins.AddRange(@("$_")) } }
		}
	}
	if ($PoolCache -and $PoolCache.Values) {
		$PoolCache.Values | ForEach-Object { $_.Balance.Keys } |
			ForEach-Object { if ($coins -notcontains "$_") { $coins.AddRange(@("$_")) } }
	}
	$epcurr = Get-ElectricityPriceCurrency
	if ($epcurr) {
		if ($coins -notcontains "$epcurr") { $coins.AddRange(@("$epcurr")) }
	}
	Remove-Variable epcurr

	$fn = [IO.Path]::Combine([Config]::BinLocation, "rates_cache_$(Get-Join "_" ($Config.Currencies | ForEach-Object { $_[0].ToLower() })).json")
	$fi = [IO.FileInfo]::new($fn);

	if ($fi.Exists -and ([datetime]::Now - $fi.LastWriteTime).TotalMinutes -le 15) {
		$data = (Get-Content $fn -Raw | ConvertFrom-Json)
		# convert to Dictionary<string, object>
		$data | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			$wallet = "$_"
			$values = [Collections.Generic.List[object]]::new()
			$data.$wallet | ForEach-Object {
				$values.Add(@($_[0], $_[1]));
			}
			$result.Add($wallet, $values)
			Remove-Variable values, wallet
		}
		return $result
	}

	$json = Get-Rest "https://min-api.cryptocompare.com/data/pricemulti?fsyms=$(Get-Join "," $coins)&tsyms=$(Get-Join "," ($Config.Currencies | ForEach-Object { $_[0] }))"

	if ($json -and $json.Response -notmatch "Error") {
		($json | ConvertTo-Json -Compress).Split(@("},", "}}"), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
			$signs = $_.Split(@(":{", "{"), [StringSplitOptions]::RemoveEmptyEntries)
			$values = [Collections.Generic.List[object]]::new()
			$signs[1].Split(@(","), [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
				$each = "$_".Split(@(":", "`""), [StringSplitOptions]::RemoveEmptyEntries)
				$values.Add(@("$($each[0])"; [MultipleUnit]::ToValueInvariant($each[1], [string]::Empty)))
			}
			$result.Add($signs[0].Replace("`"", [string]::Empty), $values)
			Remove-Variable values, signs
		}
	}
	$coins | ForEach-Object {
		$wallet = "$_"
		if (!$result.ContainsKey($wallet)) {
			$json = Get-Rest "https://api.coinbase.com/v2/exchange-rates?currency=$wallet"
			if ($json) {
				$values = [Collections.Generic.List[object]]::new()
				$Config.Currencies | ForEach-Object {
					if ([string]::Equals($_[0], $wallet, [StringComparison]::InvariantCultureIgnoreCase)) {
						$values.Add(@($wallet, [decimal]1))
					}
					<#elseif ([string]::Equals($_[0], "m$wallet", [StringComparison]::InvariantCultureIgnoreCase)) {
						$values.Add(@("m$wallet", [decimal]1000))
					}#>
					elseif ($json.data.rates."$($_[0])") {
						$values.Add(@($_[0], [decimal]$json.data.rates."$($_[0])"))
					}
				}
				$result.Add($wallet, $values)
				Remove-Variable values
			}
		}
		Remove-Variable wallet
	}

	$result | ConvertTo-Json -Depth 10 -Compress | Out-File $fn -Force

	Remove-Variable json, fi, fn, coins

	return $result
}