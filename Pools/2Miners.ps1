<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }

if (!$Config.Wallet.BTC) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine ETH on $($PoolInfo.Name) as a Priority (>0.005 ETH every 24H)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "20 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	Region = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.96 }

$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

$PoolData = @( @{ algorithm = "Ethash"; port = 2020; ssl = 12020; coin = "ETH"; api = "https://eth.2miners.com/api/accounts/{0}" } )
# $PoolCoins = $PoolData | Foreach-object { $_.coin }

try {
	if (![Config]::UseApiProxy -and $Config.ShowBalance) {
		$PoolData | ForEach-Object {
			$balance = Get-Rest ($_.api -f ($Config.Wallet.BTC))
			if ($balance) {
				$PoolInfo.Balance.Add($_.coin, [BalanceInfo]::new([decimal]$balance.stats.balance / 1000000000, [decimal]$balance.stats.immature / 1000000000))
			}
			Remove-Variable balance
		}
	}
}
catch { }

[string] $Pool_Region = "eth"
$Regions = @("eth", "us-eth", "asia-eth")
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "eth" }
	"$([eRegion]::Usa)" { $Pool_Region = "us-eth" }
	"$([eRegion]::China)" { $Pool_Region = "asia-eth" }
	"$([eRegion]::Japan)" { $Pool_Region = "asia-eth" }
}
if (![string]::IsNullOrWhiteSpace($Cfg.Region) -and $Regions -contains $Cfg.Region) {
	$Pool_Region = $Cfg.Region.ToLower();
}
$Regions = $Regions | Sort-Object @{ Expression = { if ($_ -eq $Pool_Region) { 1 } elseif ($_ -eq "asia-eth") { 3 } else { 2 } } } |
	Select-Object -First 3

$Profit = 0

# WTM profit
try {
	$wtmdata = Get-Rest "https://whattomine.com/coins/151.json?hr=1000.0&p=0.0&fee=1.0&cost=0.0&hcost=0.0&span_br=1h&span_d=1h"
	if ($wtmdata) {
		$Profit = [MultipleUnit]::ToValueInvariant($wtmdata.btc_revenue, [string]::Empty) / 1000 / 1000000;
	}
}
catch { return $PoolInfo }

if ($Profit -eq 0) { return $PoolInfo }

$PoolData | ForEach-Object {
	$Coin = $_.coin.ToUpperInvariant()
	$Pool_Algorithm = Get-Algo $_.algorithm
	if ($Pool_Algorithm -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm) {
		$Pool_Hosts = $Regions | ForEach-Object { "$_.2miners.com" }
		$Pool_Port = $_.port
		$Pool_Protocol = "stratum+tcp"
		<#if ($Config.SSL -eq $true) {
			$Pool_Protocol = "stratum+ssl"
			$Pool_Port = $_.ssl
		}#>
		$Profit = $Profit * $Pool_Variety
		$ProfitFast = $Profit
		$Profit = Set-Stat -Filename $PoolInfo.Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit

		$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
			Name = "$($PoolInfo.Name)-$($Pool_Region.ToUpper() -replace "-ETH" -replace "ETH", "EU")"
			Algorithm = $Pool_Algorithm
			Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
			Info = $Coin
			Protocol = $Pool_Protocol
			Hosts = $Pool_Hosts
			Port = $Pool_Port
			PortUnsecure = $Pool_Port
			User = "$([Config]::WalletPlaceholder -f "BTC").$([Config]::WorkerNamePlaceholder)"
			Password = "x"
			Priority = [Priority]::High
		})
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo