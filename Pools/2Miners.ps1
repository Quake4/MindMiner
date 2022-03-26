<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }

if (!$Config.Wallet.BTC) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine ETH/ETC on $($PoolInfo.Name) as a Priority (>0.005 ETH every day)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "20 min"
	Coin = "ETH"
	Region = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.96 }

$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

$PoolData = @( 
	@{ algorithm = "Ethash"; port = 2020; ssl = 12020; coin = "ETH"; wtmid = 151; api = "https://eth.2miners.com/api/accounts/{0}"; regions = @("eth", "us-eth", "asia-eth") }
	@{ algorithm = "Etсhash"; port = 1010; ssl = 11010; coin = "ETC"; wtmid = 162; api = "https://etс.2miners.com/api/accounts/{0}"; regions = @("etc", "us-etc", "asia-etc") }
)
$PoolCoins = $PoolData | Foreach-object { $_.coin }

if ([string]::IsNullOrWhiteSpace($Cfg.Coin)) {
	Write-Host "Set coin symbol from list ($([string]::Join(", ", $PoolCoins))) in '$($PoolInfo.Name).config.txt' file." -ForegroundColor Yellow
	$Cfg.Coin = $PoolData[0].coin
	Write-Host "Setted default coin as $($Cfg.Coin)." -ForegroundColor Yellow
}

if (!$PoolData | Where-Object { $_.coin -eq $Cfg.Coin.ToUpperInvariant() }) {
	Write-Host "Unknown coin `"$($Cfg.Coin)`" in '$($PoolInfo.Name).config.txt' file. Use coin from list: $([string]::Join(", ", $PoolCoins))." -ForegroundColor Red
	return $PoolInfo
}

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

$PoolData = $PoolData | Where-Object { $_.coin -eq $Cfg.Coin.ToUpperInvariant() }

[string] $Pool_Region = $PoolData.regions[0]
$Regions = $PoolData.regions
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = $Regions[0] }
	"$([eRegion]::Usa)" { $Pool_Region = $Regions[1] }
	"$([eRegion]::China)" { $Pool_Region = $Regions[2] }
	"$([eRegion]::Japan)" { $Pool_Region = $Regions[2] }
}
if (![string]::IsNullOrWhiteSpace($Cfg.Region) -and $null -ne ($Regions | Where-Object { $_ -match $Cfg.Region } | Select-Object -First)) {
	$Pool_Region = $Regions | Where-Object { $_ -match $Cfg.Region } | Select-Object -First;
}
$Regions = $Regions | Sort-Object @{ Expression = { if ($_ -eq $Pool_Region) { 1 } elseif ($_ -match "asia") { 3 } else { 2 } } } |
	Select-Object -First 3

$Profit = 0

# WTM profit
try {
	$wtmdata = Get-Rest "https://whattomine.com/coins/$($PoolData.wtmid).json?hr=1000.0&p=0.0&fee=1.0&cost=0.0&hcost=0.0&span_br=1h&span_d=1h"
	if ($wtmdata) {
		$Profit = [MultipleUnit]::ToValueInvariant($wtmdata.btc_revenue, [string]::Empty) / 1000 / 1000000;
	}
}
catch { return $PoolInfo }

if ($Profit -eq 0) { return $PoolInfo }

$PoolData | ForEach-Object {
	$Coin = $_.coin.ToUpperInvariant()
	$Pool_Algorithm = Get-Algo $_.algorithm
	if ($Pool_Algorithm) {
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
			Name = "$($PoolInfo.Name)-$($Pool_Region.ToUpper() -replace "-$($PoolData.coin)" -replace $PoolData.coin, "EU")"
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