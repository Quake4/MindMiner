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
		@{ Enabled = $true; Algorithm = "abelian"; DualAlgorithm = "alephium" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "alephium" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "alephium" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "alephium" }
		@{ Enabled = $true; Algorithm = "ethashb3"; DualAlgorithm = "alephium" }

		@{ Enabled = $true; Algorithm = "abelian"; DualAlgorithm = "ironfish" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "ironfish" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "ironfish" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "ironfish" }
		@{ Enabled = $true; Algorithm = "ethashb3"; DualAlgorithm = "ironfish" }

		@{ Enabled = $true; Algorithm = "abelian"; DualAlgorithm = "karlsenhash" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "karlsenhash" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "karlsenhash" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "karlsenhash" }
		@{ Enabled = $true; Algorithm = "ethashb3"; DualAlgorithm = "karlsenhash" }

		@{ Enabled = $true; Algorithm = "abelian"; DualAlgorithm = "pyrinhash" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "pyrinhash" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "pyrinhash" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "pyrinhash" }
		@{ Enabled = $true; Algorithm = "ethashb3"; DualAlgorithm = "pyrinhash" }

		@{ Enabled = $true; Algorithm = "abelian"; DualAlgorithm = "sha256ton" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "sha256ton" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "sha256ton" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "sha256ton" }
		@{ Enabled = $true; Algorithm = "ethashb3"; DualAlgorithm = "sha256ton" }
		
		@{ Enabled = $true; Algorithm = "abelian"; DualAlgorithm = "sha512256d" }
		@{ Enabled = $true; Algorithm = "autolykos2"; DualAlgorithm = "sha512256d" }
		@{ Enabled = $true; Algorithm = "etchash"; DualAlgorithm = "sha512256d" }
		@{ Enabled = $true; Algorithm = "ethash"; DualAlgorithm = "sha512256d" }
		@{ Enabled = $true; Algorithm = "ethashb3"; DualAlgorithm = "sha512256d" }

		@{ Enabled = $true; Algorithm = "fishhash"; DualAlgorithm = "alephium" }
		@{ Enabled = $true; Algorithm = "fishhash"; DualAlgorithm = "karlsenhash" }
		@{ Enabled = $true; Algorithm = "fishhash"; DualAlgorithm = "pyrinhash" }
		@{ Enabled = $true; Algorithm = "fishhash"; DualAlgorithm = "sha256ton" }
		@{ Enabled = $true; Algorithm = "fishhash"; DualAlgorithm = "sha512256d" }

		@{ Enabled = $true; Algorithm = "octopus"; DualAlgorithm = "alephium" }
		@{ Enabled = $true; Algorithm = "octopus"; DualAlgorithm = "karlsenhash" }
		@{ Enabled = $true; Algorithm = "octopus"; DualAlgorithm = "pyrinhash" }
		@{ Enabled = $true; Algorithm = "octopus"; DualAlgorithm = "sha256ton" }
		@{ Enabled = $true; Algorithm = "octopus"; DualAlgorithm = "sha512256d" }
)}

if (!$Cfg.Enabled) { return }

$port = [Config]::Ports[[int][eMinerType]::nVidia]
$nocolor = if ([Environment]::OSVersion.Version.Major -le 6) { "--no-tui " } else { [string]::Empty }

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

				$fee = 1
				if ($_.Algorithm -match "zil") { $fee = 0 }
				elseif (("alephium", "etchash", "ethash", "ironfish") -contains $_.Algorithm) { $fee = 0.7 }
				elseif (("nexapow", "octopus") -contains $_.Algorithm) { $fee = 2 }

				$hosts = [string]::Empty
				$Pool.Hosts | ForEach-Object {
					$hosts = Get-Join " " @($hosts, "-o [1]$($Pool.Protocol)://$_`:$($Pool.Port)")
				}
				$hosts += " -u [1]$($Pool.User) -p [1]$($Pool.Password)";
				$PoolDual.Hosts | ForEach-Object {
					$hosts = Get-Join " " @($hosts, "-o [2]$($PoolDual.Protocol)://$_`:$($PoolDual.Port)")
				}
				$hosts += " -u [2]$($PoolDual.User) -p [2]$($PoolDual.Password)";

				[MinerInfo]@{
					Pool = $(Get-FormatDualPool $Pool.PoolName() $PoolDual.PoolName())
					PoolKey = "$($Pool.PoolKey())+$($PoolDual.PoolKey())"
					Priority = $Pool.Priority
					DualPriority = $PoolDual.Priority
					Name = $Name
					Algorithm = $Algo
					DualAlgorithm = $AlgoDual
					Type = [eMinerType]::nVidia
					API = "rigel"
					URI = "https://github.com/rigelminer/rigel/releases/download/1.17.4/rigel-1.17.4-win.zip"
					Path = "$Name\rigel.exe"
					ExtraArgs = $extrargs
					Arguments = "-a $($_.Algorithm)+$($_.DualAlgorithm) $hosts -w $([Config]::WorkerNamePlaceholder) --api-bind 127.0.0.1:$port --dns-over-https --no-strict-ssl --no-watchdog --stats-interval 60 --dag-reset-mclock off $nocolor$extrargs"
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