<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-ElectricityCurrentPrice ([Parameter(Mandatory)][string] $returncurrency) {
	[decimal] $price = 0;
	$currency = Get-ElectricityPriceCurrency;
	if ($currency) {
		# { USD = { 7 = 0.1, 18 = 0.05 } }
		if ($Config.ElectricityPrice.$currency -is [PSCustomObject]) {
			$items = $Config.ElectricityPrice.$currency | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name |
				Sort-Object @{ Expression = { [decimal]$_.Name } }
			$currentHour = ([datetime]::Now - [datetime]::Today).TotalHours
			$tariff = $items[$items.Length - 1];
			for ($i = 0; $i -lt $items.Length; $i++) {
				if ($items[$i] -lt $currentHour) {
					$tariff = $items[$i];
				}
			}
			$price = [decimal]$Config.ElectricityPrice.$currency.$tariff
		}
		# { USD = 0.1 }
		else {
			$price = [decimal]$Config.ElectricityPrice.$currency;
		}
		# convert
		for ($i = 0; $i -lt $Rates[$currency].Count; $i++) {
			if ($Rates[$currency][$i][0] -eq $returncurrency) {
				$price = $price * $Rates[$currency][$i][1];
			}
		}
	}
	return $price;
}

function Get-ElectricityPriceCurrency {
	[string] $curr = $null;
	if ($Config.ElectricityPrice) {
		$curr = $Config.ElectricityPrice | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name -First 1
	}
	return $curr;
}