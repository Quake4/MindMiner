<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateConfig "Do you want to mine on $($PoolInfo.Name) (autoexchange to any coin, payout with fixed fee, need registration)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "1 hour 30 min"
	ApiKey = ""
}
if (!$Cfg) { return $PoolInfo }
if ([string]::IsNullOrWhiteSpace($Config.Login)) { return $PoolInfo }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
$Pool_Variety = 0.85
$NoExchangeCoins = @("Electroneum", "Gamecredits", "Geocoin", "Sexcoin", "Startcoin")

try {
	$Request = Get-UrlAsJson "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance -and ![string]::IsNullOrWhiteSpace($Cfg.ApiKey)) {
		$RequestBalance = Get-UrlAsJson "https://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=$($Cfg.ApiKey)"
	}
}
catch { }

if (!$Request -or !($Request.success -eq $true)) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$RequestBalance.getuserallbalances.data | Where-Object coin -EQ "bitcoin" | ForEach-Object {
		$PoolInfo.Balance.Value = [decimal]$_.confirmed
		$PoolInfo.Balance.Additional = [decimal]$_.unconfirmed
	}
}

if ($Config.SSL -eq $true) { $Pool_Protocol = "stratum+ssl" } else { $Pool_Protocol = "stratum+tcp" }

$Pool_Region = "US"
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "Europe" }
	"$([eRegion]::China)" { $Pool_Region = "Asia" }
	"$([eRegion]::Japan)" { $Pool_Region = "Asia" }
}

# exclude no exchange coins highest_buy_price = 0
$Request.return | Where-Object { $_.profit -gt 0 -and $_.highest_buy_price -gt 0 -and $NoExchangeCoins -notcontains $_.coin_name } | ForEach-Object {
	if ($_.algo -contains "cryptonight" -and $_.coin_name -contains "monero") { $_.algo = "cryptonightv7" }
	$Pool_Algorithm = Get-Algo($_.algo)
	if ($Pool_Algorithm) {
		$Pool_Host = $_.host_list.split(";") | Where-Object { $_.StartsWith($Pool_Region, [StringComparison]::InvariantCultureIgnoreCase) } | Select-Object -First 1
		$Pool_Port = $_.port
		$Coin = (Get-Culture).TextInfo.ToTitleCase($_.coin_name)
		if (!$Coin.StartsWith($_.algo)) { $Coin = $Coin.Replace($_.algo, "") }
		$Coin = $Coin.Replace("-", "").Replace("DigibyteGroestl", "Digibyte").Replace("MyriadcoinGroestl", "MyriadCoin")

		$Divisor = 1000000000
		$Profit = [decimal]$_.profit * (1 - 0.009) * $Pool_Variety / $Divisor
		$Profit = Set-Stat -Filename ($PoolInfo.Name) -Key "$Pool_Algorithm`_$Coin" -Value $Profit -Interval $Cfg.AverageProfit

		$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
			Name = $PoolInfo.Name
			Algorithm = $Pool_Algorithm
			Info = "$($Config.Region)-$Coin"
			InfoAsKey = $true
			Profit = $Profit
			Protocol = $Pool_Protocol
			Host = $Pool_Host
			Port = $Pool_Port
			PortUnsecure = $Pool_Port
			User = "$($Config.Login).$($Config.WorkerName)"
			Password = $Config.Password
		})
	}
}

$PoolInfo