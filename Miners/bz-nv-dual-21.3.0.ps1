<#
MindMiner  Copyright (C) 2017-2023  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		@{ Enabled = $true; Algorithm = "ergo"; DualAlgorithm = "kaspa" }
		@{ Enabled = $true; Algorithm = "ergo"; DualAlgorithm = "radiant" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "alph" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "ironfish" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "kaspa" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "radiant" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "alph" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "ironfish" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "kaspa" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "radiant" }
		@{ Enabled = $true; Algorithm = "octa"; DualAlgorithm = "alph" }
		@{ Enabled = $true; Algorithm = "octa"; DualAlgorithm = "ironfish" }
		@{ Enabled = $true; Algorithm = "octa"; DualAlgorithm = "kaspa" }
		@{ Enabled = $true; Algorithm = "octa"; DualAlgorithm = "radiant" }
		@{ Enabled = $true; Algorithm = "rethereum"; DualAlgorithm = "alph" }
		@{ Enabled = $true; Algorithm = "rethereum"; DualAlgorithm = "ironfish" }
		@{ Enabled = $true; Algorithm = "rethereum"; DualAlgorithm = "kaspa" }
		@{ Enabled = $true; Algorithm = "rethereum"; DualAlgorithm = "radiant" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::nVidia]

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		$AlgoDual = Get-Algo($_.DualAlgorithm)
		if ($Algo -and $AlgoDual) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			$PoolDual = Get-Pool($AlgoDual)
			if ($Pool -and $PoolDual) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$fee = 0.5
				if (("olhash", "kaspa", "kylacoin", "meowcoin", "neox", "ironfish", "ixi", "radiant", "rvn", "woodcoin", "xna") -contains $_.Algorithm) { $fee = 1 }
				elseif ($_.Algorithm -match "zil") { $fee = 0 }
				[MinerInfo]@{
					Pool = $(Get-FormatDualPool $Pool.PoolName() $PoolDual.PoolName())
					PoolKey = "$($Pool.PoolKey())+$($PoolDual.PoolKey())"
					Priority = $Pool.Priority
					DualPriority = $PoolDual.Priority
					Name = $Name
					Algorithm = $Algo
					DualAlgorithm = $AlgoDual
					Type = [eMinerType]::nVidia
					API = "bzminer"
					URI = "https://github.com/bzminer/bzminer/releases/download/v21.3.0/bzminer_v21.3.0_windows.zip"
					Path = "$Name\bzminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) -p $($Pool.Hosts[0]):$($Pool.PortUnsecure) -w $($Pool.User) --pool_password $($Pool.Password) --a2 $($_.DualAlgorithm) --p2 $($PoolDual.Hosts[0]):$($PoolDual.PortUnsecure) --w2 $($PoolDual.User) --pool_password2 $($PoolDual.Password) --no_watchdog --nvidia 1 --amd 0 --intel 0 --nc 1 --update_frequency_ms 60000 --pool_reconnect_timeout_ms $($Config.CheckTimeout)000 --http_address 127.0.0.1 --http_port $port $extrargs"
					Port = $port
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}