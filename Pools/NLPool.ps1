<#
MindMiner  Copyright (C) 2018-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename), @{
	Enabled = $false
	AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
})

if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$Sign = "BTC"
$wallets = $Config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object { "$_" -notmatch "nicehash" }
if ($wallets -is [string]) {
	$Sign = "$wallets"
}
$Wallet = $Config.Wallet.$Sign
if ($Config.Wallet."$($Cfg.Wallet)") {
	$Wallet = $Config.Wallet."$($Cfg.Wallet)"
	$Sign = $Cfg.Wallet
}
elseif (![string]::IsNullOrWhiteSpace($Cfg.Wallet)) {
	Write-Host "Wallet '$($Cfg.Wallet)' specified in file '$($PoolInfo.Name).config.txt' isn't found. $($PoolInfo.Name) disabled." -ForegroundColor Red
	return $null
}
if (!$Wallet) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }

# fake api data and broken accounting block reward - if you fix it write me
[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.5 }

try {
	$RequestStatus = Get-Rest "http://www.nlpool.nl/api/status"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance) {
		$RequestBalance = Get-Rest "http://www.nlpool.nl/api/wallet?address=$Wallet"
	}
}
catch { }

if (!$RequestStatus) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$PoolInfo.Balance.Add($Sign, [BalanceInfo]::new([decimal]($RequestBalance.balance), [decimal]($RequestBalance.unsold)))
}

$FixCurrentHash = @("equihash125", "equihash144", "equihash192")

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Algo = $RequestStatus.$_
	$Pool_Algorithm = Get-Algo $Algo.name
	if ($Pool_Algorithm -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$Algo.actual_last24h -ne $Algo.estimate_last24h -and [decimal]$Algo.estimate_current -gt 0) {
		$Pool_Host = "mine.nlpool.nl"
		$Pool_Port =  $Algo.port
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }
		$Divisor = 1000000 * $Algo.mbtc_mh_factor

		# convert to one dimension and decimal
		$Algo.actual_last24h = [decimal]$Algo.actual_last24h / 1000
		$Algo.estimate_current = [decimal]$Algo.estimate_current
		# fix fake current profit
		if ($FixCurrentHash -contains $Pool_Algorithm) {
			$Algo.estimate_current /= 2
		}
		# fix very high or low daily changes
		if ($Algo.estimate_current -gt $Algo.actual_last24h * $Config.MaximumAllowedGrowth) { $Algo.estimate_current = $Algo.actual_last24h * $Config.MaximumAllowedGrowth }
		if ($Algo.actual_last24h -gt $Algo.estimate_current * $Config.MaximumAllowedGrowth) { $Algo.actual_last24h = $Algo.estimate_current * $Config.MaximumAllowedGrowth }

		[decimal] $Profit = ([Math]::Min($Algo.estimate_current, $Algo.actual_last24h) + $Algo.estimate_current * ((101 - $Algo.coins) / 100)) / 2
		$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
		$ProfitFast = $Profit
		if ($Profit -gt 0) {
			$Profit = Set-Stat -Filename $PoolInfo.Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit
		}

		if ([int]$Algo.workers -ge $Config.MinimumMiners -or $global:HasConfirm) {
			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
				Protocol = "stratum+tcp"
				Hosts = @($Pool_Host)
				Port = $Pool_Port
				PortUnsecure = $Pool_Port
				User = "$([Config]::WalletPlaceholder -f $Sign).$([Config]::WorkerNamePlaceholder)"
				Password = Get-Join "," @("c=$Sign", $Pool_Diff)
				Priority = if ($AllAlgos.EnabledAlgorithms -contains $Pool_Algorithm -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) { [Priority]::High } else { [Priority]::Normal }
			})
		}
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo