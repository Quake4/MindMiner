<#
MindMiner  Copyright (C) 2019-2023  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash125" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "progpow" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::AMD]

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$alg = [string]::Empty
				switch ($_.Algorithm) {
					"beam" { $alg = "--par=150,5" }
					"beamV2" { $alg = "--par=150,5,3" }
					"beamV3" { $alg = "--par=beam3" }
					"equihash125" { $alg = "--par=125,4" }
					"equihash144" { $alg = "--par=144,5" }
					"equihash192" { $alg = "--par=192,7" }
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
				$fee = if ($_.Algorithm -match "ethash" -or $_.Algorithm -match "etchash") { 0.75 }
				elseif ($_.Algorithm -match "kawpow" -or $_.Algorithm -match "progpow") { 1 }
				else { 2 }
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "miniz"
					URI = "https://mindminer.online/miners/miniz-20c3.zip"
					Path = "$Name\miniz.exe"
					ExtraArgs = $extrargs
					Arguments = "$alg $pools -a $port --latency --show-shares --amd --stat-int=60 $extrargs"
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