<#
MindMiner  Copyright (C) 2018-2020  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::AMD) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnr" }
		[AlgoInfoEx]@{ Enabled = $false; Algorithm = "cnv8" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn_conceal" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn_heavy" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn_haven" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cn_saber" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnv8_dbl" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnv8_half" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnv8_rwz" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnv8_trtl" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cnv8_upx2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckatoo31_grin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "cuckarood29_grin" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2rev3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "lyra2z" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "trtl_chukwa" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "mtp" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "phi2-lux" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "veil" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16r" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16rv2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16rt" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "x16s" }
)}

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$fee = 2.5
				if ($_.Algorithm -match "lyra2z" -or $_.Algorithm -match "phi2") { $fee = 3}
				elseif ($_.Algorithm -match "kawpow") { $fee = 2 }
				elseif ($_.Algorithm -match "ethash") { $fee = 1 }
				if ($_.Algorithm -match "veil") { $_.Algorithm = "x16rt" }
				if ($_.Algorithm -match "phi2-lux") { $_.Algorithm = "phi2" }
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$hosts = Get-Join " " @($hosts, "-o stratum+tcp://$_`:$($Pool.PortUnsecure) -u $($Pool.User) -p $($Pool.Password)")
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::AMD
					API = "teamred"
					URI = "https://github.com/todxx/teamredminer/releases/download/0.7.1/teamredminer-v0.7.1-win.zip"
					Path = "$Name\teamredminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $hosts --api_listen=127.0.0.1:4028 --platform=$([Config]::AMDPlatformId) $extrargs"
					Port = 4028
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = $fee
				}
			}
		}
	}
}