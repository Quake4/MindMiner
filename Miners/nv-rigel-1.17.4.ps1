<#
MindMiner  Copyright (C) 2018-2024  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

if ([Config]::ActiveTypes -notcontains [eMinerType]::nVidia) { exit }
if (![Config]::Is64Bit) { exit }
if ([Config]::CudaVersion -lt [version]::new(8, 0)) { return }

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = ReadOrCreateMinerConfig "Do you want use to mine the '$Name' miner" ([IO.Path]::Combine($PSScriptRoot, $Name + [BaseConfig]::Filename)) @{
	Enabled = $true
	BenchmarkSeconds = 120
	ExtraArgs = $null
	Algorithms = @(
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "abelian" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "alephium" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "autolykos2" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "etchash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ethashb3" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "fishhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "ironfish" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "karlsenhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "kawpow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "nexapow" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "octopus" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "pyrinhash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha256ton" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "sha512256d" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "xelishash" }
		[AlgoInfoEx]@{ Enabled = $true; Algorithm = "zil" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::nVidia]
$nocolor = if ([Environment]::OSVersion.Version.Major -le 6) { "--no-tui " } else { [string]::Empty }

$Cfg.Algorithms | ForEach-Object {
	if ($_.Enabled) {
		$Algo = Get-Algo($_.Algorithm)
		if ($Algo) {
			# find pool by algorithm
			$Pool = Get-Pool($Algo)
			if ($Pool) {
				$extrargs = Get-Join " " @($Cfg.ExtraArgs, $_.ExtraArgs)

				$fee = 1
				if ($_.Algorithm -match "zil") { $fee = 0 }
				elseif (("alephium", "etchash", "ethash", "ironfish") -contains $_.Algorithm) { $fee = 0.7 }
				elseif (("nexapow", "octopus") -contains $_.Algorithm) { $fee = 2 }

				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$hosts = Get-Join " " @($hosts, "-o $($Pool.Protocol)://$_`:$($Pool.Port)")
				}

				[MinerInfo]@{
					Pool = $Pool.PoolName()
					PoolKey = $Pool.PoolKey()
					Priority = $Pool.Priority
					Name = $Name
					Algorithm = $Algo
					Type = [eMinerType]::nVidia
					API = "rigel"
					URI = "https://github.com/rigelminer/rigel/releases/download/1.17.4/rigel-1.17.4-win.zip"
					Path = "$Name\rigel.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm) $hosts -u $($Pool.User) -p $($Pool.Password) -w $([Config]::WorkerNamePlaceholder) --api-bind 127.0.0.1:$port --dns-over-https --no-strict-ssl --no-watchdog --stats-interval 60 --dag-reset-mclock off $nocolor$extrargs"
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