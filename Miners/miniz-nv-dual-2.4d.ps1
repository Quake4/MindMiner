<#
MindMiner  Copyright (C) 2019-2024  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(8, 0)) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		@{ Enabled = $true; Algorithm = "beam"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "beam"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "beamV2"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "beamV2"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "beamV3"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "beamV3"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "equihash125"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "equihash125"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "equihash144"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "equihash144"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "equihash192"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "equihash192"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "equihash210"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "equihash210"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "grimm"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "grimm"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "ethashb3"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "ethashb3"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "kawpow"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "kawpow"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "octopus"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "octopus"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "progpow"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "progpow"; DualAlgorithm = "karlsen" }
		@{ Enabled = $true; Algorithm = "ubqhash"; DualAlgorithm = "pyrin" }
		@{ Enabled = $true; Algorithm = "ubqhash"; DualAlgorithm = "karlsen" }
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
				$alg = [string]::Empty
				switch ($_.Algorithm) {
					"beam" { $alg = "--par=150,5" }
					"beamV2" { $alg = "--par=150,5,3" }
					"beamV3" { $alg = "--par=beam3" }
					"equihash125" { $alg = "--par=125,4" }
					"equihash144" { $alg = "--par=144,5" }
					"equihash192" { $alg = "--par=192,7" }
					# "equihashZCL" { $alg = "--par=192,7 --pers=ZcashPoW" }
					"equihash210" { $alg = "--par=210,9" }
					"equihash96" { $alg = "--par=96,5" }
					"equihashBTG" { $alg = "--par=144,5 --pers=BgoldPoW" }
					"grimm" { $alg = "--par=150,5 --pers=GrimmPOW" }
					"zhash" { $alg = "--par=144,5" }
					default { $alg = "--par=$_" }
				}
				if (!($extrargs -match "-pers" -or $alg -match "-pers")) {
					$alg = Get-Join " " @($alg, "--pers=auto")
				}
				$user = $Pool.User
				if ($user -notmatch ".$([Config]::WorkerNamePlaceholder)" -and !$user.Replace([Config]::WalletPlaceholder, ([string]::Empty)).Contains(".")) {
					$user = "$user.$([Config]::WorkerNamePlaceholder)"
				}
				if ($Pool.Protocol -match "ssl") { $user = "ssl://$user" }
				$pools = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$pools = Get-Join " " @($pools, "--url=$user@$_`:$($Pool.Port) -p $($Pool.Password)")
				}
				# second pool
				$user = $PoolDual.User
				if ($user -notmatch ".$([Config]::WorkerNamePlaceholder)" -and !$user.Replace([Config]::WalletPlaceholder, ([string]::Empty)).Contains(".")) {
					$user = "$user.$([Config]::WorkerNamePlaceholder)"
				}
				if ($PoolDual.Protocol -match "ssl") { $user = "ssl://$user" }
				$PoolDual.Hosts | ForEach-Object {
					$pools = Get-Join " " @($pools, "--url2=$user@$_`:$($PoolDual.Port) -p $($PoolDual.Password)")
				}
				$fee = 2
				if (("etchash", "ethash") -contains $_.Algorithm) { $fee = 0.75 }
				elseif (("karlsen", "pyrin") -contains $_.Algorithm) { $fee = 0.8 }
				elseif (("ethashb3", "evrprogpow", "kawpow", "progpow") -contains $_.Algorithm) { $fee = 1 }
				[MinerInfo]@{
					Pool = $(Get-FormatDualPool $Pool.PoolName() $PoolDual.PoolName())
					PoolKey = "$($Pool.PoolKey())+$($PoolDual.PoolKey())"
					Priority = $Pool.Priority
					DualPriority = $PoolDual.Priority
					Name = $Name
					Algorithm = $Algo
					DualAlgorithm = $AlgoDual
					Type = [eMinerType]::nVidia
					API = "minizdual"
					URI = "https://mindminer.online/miners/miniz-24d.zip"
					Path = "$Name\miniz.exe"
					ExtraArgs = $extrargs
					Arguments = "$alg $pools -a $port --latency --show-shares --nvidia --stat-int=60 --retrydelay=$($Config.CheckTimeout) $extrargs"
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