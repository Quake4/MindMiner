<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Include.ps1

if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $false
	BenchmarkSeconds = 180
	ExtraArgs = $null
	Algorithms = @(
		@{ Enabled = $false; Algorithm = "ethash"; DualAlgorithm = "blake2s"; ExtraArgs = "-nofee" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		$DualAlgo = Get-Algo($_.DualAlgorithm)
		if ($Algo -and $DualAlgo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			$DualPool = Get-Pool($DualAlgo)
			if ($Pool -and $DualPool) {
				$proto = $Pool.Protocol
				if (!$Pool.Protocol.Contains("ssl")) {
					$proto = "stratum"
				}
				$proto = $proto.Replace("stratum", "ethash")
				if ($Pool.Name -contains "nicehash") {
					$proto = $proto.Replace("ethash", "ethstratum")
				}
				$DualPassword = $DualPool.Password.Replace(",", "%2C")
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = "$($Pool.PoolName())+$($DualPool.PoolName())"
					PoolKey = "$($Pool.PoolKey())+$($DualPool.PoolKey())"
					Name = $Name
					Algorithm = $Algo
					DualAlgorithm = $DualAlgo
					Type = [eMinerType]::nVidia
					API = "bminerdual"
					URI = "https://www.bminercontent.com/releases/bminer-lite-v8.0.0-32928c5-amd64.zip"
					Path = "$Name\bminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-uri $proto`://$($Pool.User):$($Pool.Password)@$($Pool.Host):$($Pool.Port) -uri2 blake2s://$($DualPool.User):$DualPassword@$($DualPool.Host):$($DualPool.Port) -watchdog=false -api 127.0.0.1:1880 $extrargs"
					Port = 1880
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
					Fee = if ($extrargs.ToLower().Contains("nofee")) { 0 } else { 0.65 }
				}
			}
		}
	}
}