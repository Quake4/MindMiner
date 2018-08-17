<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename), @{
	Enabled = $true
	BenchmarkSeconds = 90
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihashBTG" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash192" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash144" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "equihash96" }
)})

if (!$Cfg.Enabled) { return }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$alg = [string]::Empty
				switch ($Algo) {
					"equihashBTG" { $alg = "--algo 144_5 --pers BgoldPoW" }
					"equihash192" { $alg = "--algo 192_7" }
					"equihash144" { $alg = "--algo 144_5" }
					"equihash96" { $alg = "--algo 96_5" }
				}
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs, $alg)
				if (!($extrargs -match "--pers")) {
					$extrargs = Get-Join " " @($extrargs, "--pers auto") 
				}
				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "ewbf"
					URI = "http://mindminer.online/miners/nVidia/ewbf.v05.zip"
					Path = "$Name\miner.exe"
					ExtraArgs = $extrargs
					Arguments = "--api --server $($Pool.Host) --user $($Pool.User) --pass $($Pool.Password) --port $($Pool.PortUnsecure) --eexit 1 --fee 0 $extrargs"
					Port = 42000
					BenchmarkSeconds = if ($_.BenchmarkSeconds) { $_.BenchmarkSeconds } else { $Cfg.BenchmarkSeconds }
					RunBefore = $_.RunBefore
					RunAfter = $_.RunAfter
				}
			}
		}
	}
}