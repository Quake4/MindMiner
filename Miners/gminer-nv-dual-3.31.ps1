<#
MindMiner  Copyright (C) 2018-2023  Oleg Samsonov aka Quake4
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
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "kheavyhash" }
		@{ Enabled = $true; Algorithm = "octopus"; DualAlgorithm = "kheavyhash" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "kheavyhash" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "kheavyhash" }
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
				$benchsecs = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
				$fee = if (("autolykos2", "octopus") -contains $_.Algorithm) { 3 } else { 2 }
				$pec = if ($extrargs -match "--electricity_cost") { [string]::Empty } else { "--pec 0 " }

				$hosts = [string]::Empty

				$user = $Pool.User
				if ($user -notmatch ".$([Config]::WorkerNamePlaceholder)" -and !$user.Replace([Config]::WalletPlaceholder, ([string]::Empty)).Contains(".")) {
					$user = "$user.$([Config]::WorkerNamePlaceholder)"
				}
				$ssl = "0"
				if ($Pool.Protocol -match "ssl") { $ssl = "1" }
				$Pool.Hosts | ForEach-Object { $hosts = Get-Join " " @($hosts, "-s $_`:$($Pool.Port) -u $user -p $($Pool.Password) --ssl $ssl") }

				$user = $PoolDual.User
				if ($user -notmatch ".$([Config]::WorkerNamePlaceholder)" -and !$user.Replace([Config]::WalletPlaceholder, ([string]::Empty)).Contains(".")) {
					$user = "$user.$([Config]::WorkerNamePlaceholder)"
				}
				$ssl = "0"
				if ($PoolDual.Protocol -match "ssl") { $ssl = "1" }
				$PoolDual.Hosts | ForEach-Object { $hosts = Get-Join " " @($hosts, "--dserver $_`:$($PoolDual.Port) --duser $user --dpass $($PoolDual.Password) --dssl $ssl") }

				[MinerInfo]@{
					Pool = $(if ($Pool.PoolName() -eq $PoolDual.PoolName()) { "$($Pool.PoolName())" } else { "$($Pool.PoolName())+$($PoolDual.PoolName())" })
					PoolKey = "$($Pool.PoolKey())+$($PoolDual.PoolKey())"
					Priority = $Pool.Priority
					DualPriority = $PoolDual.Priority
					Name = $Name
					Algorithm = $Algo
					DualAlgorithm = $AlgoDual
					Type = [eMinerType]::nVidia
					API = "gminer"
					URI = "https://github.com/develsoftware/GMinerRelease/releases/download/3.31/gminer_3_31_windows64.zip"
					Path = "$Name\miner.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) --dalgo $($_.DualAlgorithm) $hosts --api 127.0.0.1:$port $pec-w 0 --cuda 1 --opencl 0 $extrargs"
					Port = $port
					BenchmarkSeconds = $benchsecs
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}