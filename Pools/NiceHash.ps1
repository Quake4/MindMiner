<#
MindMiner  Copyright (C) 2017-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::UseApiProxy) { return $null }

if ($Config.Wallet.BTC -and $Config.Wallet.NiceHashNew -and $Config.Wallet.BTC -ne $Config.Wallet.NiceHashNew) {
	if (!$Config.Wallet.NiceHash -or $Config.Wallet.NiceHash -ne $Config.Wallet.NiceHashNew) {
		Write-Host "Please change 'NiceHashNew' wallet to 'NiceHash' wallet in 'config.txt' file." -ForegroundColor Yellow
		Start-Sleep -Seconds ($Config.CheckTimeout)
	}
}

if (!$Config.Wallet.BTC -and !$Config.Wallet.NiceHash) { return $null }

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreatePoolConfig "Do you want to mine on $($PoolInfo.Name) (>0.1 BTC every 24H, >0.001 BTC ~ weekly)" ([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	AverageProfit = "20 min"
	EnabledAlgorithms = $null
	DisabledAlgorithms = $null
	Region = $null
}
if ($global:AskPools -eq $true -or !$Cfg) { return $null }

if ($Config.Wallet.NiceHash) {
	$Wallet = $Config.Wallet.NiceHash
	$Sign = "NiceHash"
	$Fee = 2
} else {
	$Wallet = $Config.Wallet.BTC
	$Sign = "BTC"
	$Fee = 5
}

if (!$Wallet) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
$PoolInfo.AverageProfit = $Cfg.AverageProfit

if (!$Cfg.Enabled) { return $PoolInfo }
[decimal] $Pool_Variety = if ($Cfg.Variety) { $Cfg.Variety } else { 0.95 }

if ($Config.Wallet.BTC -eq $Config.Wallet.NiceHash) {
	Write-Host "Please remove NiceHash wallet from 'config.txt' since it matches the BTC wallet. NiceHash wallet only for internal NiceHash wallets." -ForegroundColor Yellow
	Start-Sleep -Seconds ($Config.CheckTimeout)
}

try {
	$RequestAlgo = Get-UrlAsJson "https://api2.nicehash.com/main/api/v2/mining/algorithms"
}
catch { return $PoolInfo }

try {
	$RequestInfo = Get-UrlAsJson "https://api2.nicehash.com/main/api/v2/public/simplemultialgo/info/"
}
catch { return $PoolInfo }

try {
	if ($Config.ShowBalance) {
		$RequestBalance = Get-UrlAsJson "https://api2.nicehash.com/main/api/v2/mining/external/$Wallet/rigs"
	}
}
catch { }

if (!$RequestAlgo -or !$RequestInfo) { return $PoolInfo }
$PoolInfo.HasAnswer = $true
$PoolInfo.AnswerTime = [DateTime]::Now

if ($RequestBalance) {
	$PoolInfo.Balance.Add("BTC", [BalanceInfo]::new([decimal]$RequestBalance.externalBalance, [decimal]$RequestBalance.unpaidAmount))
}

[string] $Pool_Region = "usa"
$Regions = @( "eu", "usa", "hk", "jp", "in", "br" )
switch ($Config.Region) {
	"$([eRegion]::Europe)" { $Pool_Region = "eu" }
	"$([eRegion]::China)" { $Pool_Region = "hk" }
	"$([eRegion]::Japan)" { $Pool_Region = "jp" }
}
if (![string]::IsNullOrWhiteSpace($Cfg.Region) -and $Regions -contains $Cfg.Region) {
	$Pool_Region = $Cfg.Region.ToLower();
}

$paying = [Collections.Generic.Dictionary[string, decimal]]::new()

$RequestInfo.miningAlgorithms | Where-Object paying -GT 0 | ForEach-Object {
	$paying.Add($_.algorithm.ToLower(), [decimal]$_.paying)
}

$RequestAlgo.miningAlgorithms | Where-Object enabled | ForEach-Object {
	$alg = $_.algorithm.ToLower()
	$Pool_Algorithm = Get-Algo($alg)
	if ($Pool_Algorithm -and (!$Cfg.EnabledAlgorithms -or $Cfg.EnabledAlgorithms -contains $Pool_Algorithm) -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm) {
		$Pool_Host = $alg + ".$Pool_Region.nicehash.com"
		$Pool_Port = $_.port
		$Pool_Diff = if ($AllAlgos.Difficulty.$Pool_Algorithm) { "d=$($AllAlgos.Difficulty.$Pool_Algorithm)" } else { [string]::Empty }
		$Pool_Protocol = "stratum+tcp"
<#		if ($Config.SSL -eq $true) {
			if ($Pool_Algorithm -contains "equihash") {
				$Pool_Protocol = "stratum+ssl"
				$Pool_Port = "3" + $Pool_Port
			}
		}
#>
		$Profit = $paying.$alg * (100 - $Fee) / 100 * $Pool_Variety / 100000000
		if ($Profit -gt 0) {
			$ProfitFast = $Profit
			$Profit = Set-Stat -Filename $PoolInfo.Name -Key $Pool_Algorithm -Value $Profit -Interval $Cfg.AverageProfit

			$PoolInfo.Algorithms.Add([PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Info = $Pool_Region.ToUpper()
				InfoAsKey = $true
				Profit = if (($Config.Switching -as [eSwitching]) -eq [eSwitching]::Fast) { $ProfitFast } else { $Profit }
				Protocol = $Pool_Protocol
				Host = $Pool_Host
				Port = $Pool_Port
				PortUnsecure = $_.port
				User = "$(([Config]::WalletPlaceholder -f $Sign)).$([Config]::WorkerNamePlaceholder)"
				Password = if (![string]::IsNullOrWhiteSpace($Pool_Diff)) { $Pool_Diff } else { $Config.Password }
			})
		}
	}
}

Remove-Stat -Filename $PoolInfo.Name -Interval $Cfg.AverageProfit

$PoolInfo