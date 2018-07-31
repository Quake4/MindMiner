<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }
if (!$Config.Wallet.BTC) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateConfig "Do you want to mine on $($PoolInfo.Name) (>0.003 BTC every 24H)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $false
	AverageProfit = "45 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$Wallet = $Config.Wallet.BTC
$Sign = "BTC"

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }

[decimal] $Pool_Variety = 0.80

try {
	$RequestStatus = Get-UrlAsJson "http://api.blazepool.com/status"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance) {
		$RequestBalance = Get-UrlAsJson "http://api.blazepool.com/wallet/$Wallet"
	}
}
catch { }

if (!$RequestStatus) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$PoolInfo.Balance.Add($Sign, [BalanceInfo]::new([decimal]($RequestBalance.balance), [decimal]($RequestBalance.unsold)))
}

$RequestStatus | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
	$Pool_Algorithm = Get-Algo($RequestStatus.$_.name)
	if ($Pool_Algorithm -and (!$Cfg.EnabledAlgorithms -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm -and
		$RequestStatus.$_.actual_last24h -ne $RequestStatus.$_.estimate_last24h -and [decimal]$RequestStatus.$_.actual_last24h -gt 0.000000001 -and [decimal]$RequestStatus.$_.estimate_current -gt 0) {
		$Pool_Host = "$($RequestStatus.$_.name).mine.blazepool.com"
		$Pool_Port = $RequestStatus.$_.port
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }
		$Divisor = 1000000 * $RequestStatus.$_.mbtc_mh_factor

		# convert to one dimension and decimal
		$Algo = $RequestStatus.$_
		$Algo.actual_last24h = [decimal]$Algo.actual_last24h / 1000
		$Algo.estimate_last24h = [decimal]$Algo.estimate_last24h
		$Algo.estimate_current = [decimal]$Algo.estimate_current
		# fix very high or low daily changes
		if ($Algo.estimate_last24h -gt $Algo.actual_last24h * [Config]::MaxTrustGrow) { $Algo.estimate_last24h = $Algo.actual_last24h * [Config]::MaxTrustGrow }
		if ($Algo.actual_last24h -gt $Algo.estimate_last24h * [Config]::MaxTrustGrow) { $Algo.actual_last24h = $Algo.estimate_last24h * [Config]::MaxTrustGrow }
		if ($Algo.estimate_last24h -gt $Algo.estimate_current * [Config]::MaxTrustGrow) { $Algo.estimate_last24h = $Algo.estimate_current * [Config]::MaxTrustGrow }

		$Profit = $Algo.estimate_current * ((100 - $Algo.coins * 2) / 100) * [Config]::CurrentOf24h + ([Math]::Min($Algo.estimate_last24h, $Algo.actual_last24h) + $Algo.actual_last24h) / 2 * (1 - [Config]::CurrentOf24h)
		$Profit = $Profit * (1 - [decimal]$Algo.fees / 100) * $Pool_Variety / $Divisor
		$ProfitFast = $Profit
		$Profit = Set-Stat -Filename $PoolInfo.Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit

		if ([int]$RequestStatus.$_.workers -ge $Config.MinimumMiners) {
			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
				Protocol = "stratum+tcp"
				Host = $Pool_Host
				Port = $Pool_Port
				PortUnsecure = $Pool_Port
				User = ([Config]::WalletPlaceholder -f $Sign)
				Password = Get-Join "," @("ID=$([Config]::WorkerNamePlaceholder)", "c=BTC", $Pool_Diff)
			})
		}
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo