<#
MindMiner  Copyright (C) 2017-2025  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }

if (!$Config.Wallet.BTC) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine ERG/ETC/RVN on $($PoolInfo.Name)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "20 min"
	Region = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.95 }

$PoolData = @(
	#@{ algorithm = "ethash"; port = 2020; ssl = 12020; coin = "ETH"; api = "https://eth.2miners.com/api/accounts/{0}"; regions = @("eth", "us-eth", "asia-eth") }
	@{ algorithm = "autolykos2"; port = 8888; ssl = 18888; coin = "ERG"; api = "https://erg.2miners.com/api/accounts/{0}"; regions = @("erg", "us-erg", "asia-erg"); }
	@{ algorithm = "etchash"; port = 1010; ssl = 11010; coin = "ETC"; api = "https://etc.2miners.com/api/accounts/{0}"; regions = @("etc", "us-etc", "asia-etc"); }
	@{ algorithm = "kawpow"; port = 6060; ssl = 16060; coin = "RVN"; api = "https://rvn.2miners.com/api/accounts/{0}"; regions = @("rvn", "us-rvn", "asia-rvn"); }
	@{ algorithm = "kawpow"; port = 2020; ssl = 12020; coin = "CLORE"; api = "https://clore.2miners.com/api/accounts/{0}"; regions = @("clore", "clore", "clore"); }
	@{ algorithm = "kawpow"; port = 6060; ssl = 16060; coin = "XNA"; api = "https://xna.2miners.com/api/accounts/{0}"; regions = @("xna", "xna", "xna"); }
	@{ algorithm = "kheavyhash"; port = 2020; ssl = 12020; coin = "KAS"; api = "https://kas.2miners.com/api/accounts/{0}"; regions = @("kas", "us-kas", "asia-kas"); }
	#@{ algorithm = "equihash192"; port = 1010; ssl = 11010; coin = "ZEC"; api = "https://zec.2miners.com/api/accounts/{0}"; regions = @("zec", "us-zec", "asia-zec"); }
	@{ algorithm = "nexapow"; port = 5050; ssl = 15050; coin = "NEXA"; api = "https://nexa.2miners.com/api/accounts/{0}"; regions = @("nexa", "nexa", "nexa"); }
)
$PoolCoins = $PoolData | Foreach-object { $_.coin }

$coin = $Cfg.Coin
if ($coin -match "ERGO") {
	$coin = "ERG"
}

if (![string]::IsNullOrWhiteSpace($coin) -and !($PoolData | Where-Object { $_.coin -eq $coin.ToUpperInvariant() })) {
	Write-Host "Unknown coin `"$coin`" in '$($PoolInfo.Name).config.txt' file. Use coin from list: $([string]::Join(", ", $PoolCoins))." -ForegroundColor Red
	return $PoolInfo
}

try {
	$ProfitRequest = Get-Rest "https://api.mindminer.online/profit.json"
}
catch {
	return $PoolInfo
}

if (!$ProfitRequest) { return $PoolInfo }

$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

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

$PoolData | ForEach-Object {
	$Pool_Algorithm = Get-Algo $_.algorithm
	if ($Pool_Algorithm) {
		$Pool_Profit = $ProfitRequest."$($_.coin)";
		if ($Pool_Profit) {

			[string] $Pool_Region = $_.regions[0]
			$Regions = $_.regions
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
			
			$Pool_Hosts = $Regions | ForEach-Object { "$_.2miners.com" }
			$Pool_Protocol = "stratum+tcp"
			$Pool_Port = $_.port
			if ($Config.SSL -eq $true) {
				$Pool_Protocol = "stratum+ssl"
				$Pool_Port = $_.ssl
			}
			$Profit = $Pool_Profit.profit * $Pool_Variety
			$ProfitFast = $Profit
			$Profit = Set-Stat -Filename $PoolInfo.Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit

			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = "$($PoolInfo.Name)-$($Pool_Region.ToUpper() -replace "-$($_.coin)" -replace $_.coin, "EU")"
				Algorithm = $Pool_Algorithm
				Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
				Info = $_.coin
				Protocol = $Pool_Protocol
				Hosts = $Pool_Hosts
				Port = $Pool_Port
				PortUnsecure = $_.port
				User = "$([Config]::WalletPlaceholder -f "BTC").$([Config]::WorkerNamePlaceholder)"
				Password = "x"
				Priority = if ($AllAlgos.EnabledAlgorithms -contains $Pool_Algorithm -or $coin -match $_.coin) { [Priority]::High } else { [Priority]::Normal }
			})
		}
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo