<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $false
	BenchmarkSeconds = 300
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
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)
				[MinerInfo]@{
					Pool = if ($Pool.PoolName() -eq $DualPool.PoolName()) { "$($Pool.PoolName())" } else { "$($Pool.PoolName())+$($DualPool.PoolName())" }
					PoolKey = "$($Pool.PoolKey())+$($DualPool.PoolKey())"
					Name = $Name
					Algorithm = $Algo
					DualAlgorithm = $DualAlgo
					Type = [eMinerType]::nVidia
					API = "bminerdual"
					URI = "https://www.bminercontent.com/releases/bminer-lite-v10.1.0-1323b4f-amd64.zip"
					Path = "$Name\bminer.exe"
					ExtraArgs = $extrargs
					Arguments = "-uri ethstratum://$($Pool.User):$($Pool.Password)@$($Pool.Host):$($Pool.Port) -uri2 $($_.DualAlgorithm)://$($DualPool.User):$($DualPool.Password.Replace(",", "%2C"))@$($DualPool.Host):$($DualPool.Port) -watchdog=false -api 127.0.0.1:1880 $extrargs"
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