<#
MindMiner  Copyright (C) 2017-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if ([string]::IsNullOrWhiteSpace($Config.Login)) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine on $($PoolInfo.Name) (autoexchange to any coin, payout with fixed fee, need registration)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	ApiKey = [string]::Empty
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.85 }

try {
	$Request = Get-Rest "https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics"
}
catch { return $PoolInfo }

try {
	if (![Config]::UseApiProxy -and $Config.ShowBalance -and ![string]::IsNullOrWhiteSpace($Cfg.ApiKey)) {
		$RequestBalance = Get-Rest "https://miningpoolhub.com/index.php?page=api&action=getuserallbalances&api_key=$($Cfg.ApiKey)"
	}
}
catch { }

if (!$Request -or !($Request.success -eq $true)) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$RequestBalance.getuserallbalances.data | ForEach-Object {
		$sign = if ($_.coin -eq "bitcoin") { "BTC" }
		elseif ($_.coin -eq "ravencoin") { "RVN" }
		elseif ($_.coin -eq "ethereum") { "ETH" }
		elseif ($_.coin -eq "ethereum-classic") { "ETC" }
		else { (Get-Culture).TextInfo.ToTitleCase($_.coin) }
		if ($sign -eq "BTC" -or $_.confirmed -gt 0 -or $_.unconfirmed -gt 0) {
			$PoolInfo.Balance.Add($sign, [BalanceInfo]::new([decimal]($_.confirmed), [decimal]($_.unconfirmed)))
		}
	}
}

$Pool_Region = "US"
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "Europe" }
	"$([eRegion]::China)" { $Pool_Region = "Asia" }
	"$([eRegion]::Japan)" { $Pool_Region = "Asia" }
}

# exclude no exchange coins => $_.dovewallet_buy_price -gt 0 -or $_.poloniex_buy_price -gt 0
$Request.return | Where-Object { $_.profit -gt 0 -and ($_.dovewallet_buy_price -gt 0 -or $_.poloniex_buy_price -gt 0) } | ForEach-Object {
	$Pool_Algorithm = Get-Algo $_.algo
	if ($Pool_Algorithm -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm) {
		$Pool_Hosts = $_.host_list.split(";") | Sort-Object @{ Expression = { if ($_.StartsWith($Pool_Region, [StringComparison]::InvariantCultureIgnoreCase)) { 1 } else { 2 } } } | Select-Object -First 3
		$Pool_Port = $_.port
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { $Config.Password }
		$Pool_Protocol = "stratum+tcp"
		if ($Config.SSL -eq $true) {
			if ($Pool_Algorithm -contains "equihash") {
				$Pool_Protocol = "stratum+ssl"
			}
		}
		
		$Profit = [decimal]$_.profit * (1 - $_.fee / 100 - 0.003) * $Pool_Variety / 1000000000
		$ProfitFast = $Profit
		$Profit = Set-Stat -Filename $PoolInfo.Name -Key "$Pool_Algorithm`_$($_.symbol)" -Value $Profit -Interval $Cfg.AverageProfit

		if ($_.workers -ge $Config.MinimumMiners) {
			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Info = "$($Pool_Region -replace "Europe", "EU" -replace "Asia", "AS")-$($_.symbol)"
				InfoAsKey = $true
				Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
				Protocol = $Pool_Protocol
				Hosts = $Pool_Hosts
				Port = $Pool_Port
				PortUnsecure = $Pool_Port
				User = "$([Config]::LoginPlaceholder).$([Config]::WorkerNamePlaceholder)"
				Password = $Pool_Diff
				Priority = if ($AllAlgos.EnabledAlgorithms -contains $Pool_Algorithm -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) { [Priority]::High } else { [Priority]::Normal }
			})
		}
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo