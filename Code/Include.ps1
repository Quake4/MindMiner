<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\WebRequest.ps1
. .\Code\SummaryInfo.ps1
. .\Code\AlgoInfo.ps1
. .\Code\PoolInfo.ps1
. .\Code\MinerInfo.ps1
. .\Code\BaseConfig.ps1
. .\Code\Get-ProcessOutput.ps1
. .\Code\Get-CPUFeatures.ps1
. .\Code\Get-AMDPlatformId.ps1
. .\Code\Get-ManagementObject.ps1
. .\Code\Config.ps1
. .\Code\MinerProfitInfo.ps1
. .\Code\HumanInterval.ps1
. .\Code\StatInfo.ps1
. .\Code\MultipleUnit.ps1
. .\Code\Start-Command.ps1
. .\Code\MinerProcess.ps1
. .\Code\Get-Prerequisites.ps1
. .\Code\Get-Config.ps1
. .\Code\Get-Speed.ps1
. .\Code\Update-Miner.ps1
. .\Code\Get-PoolInfo.ps1
. .\Code\Get-RateInfo.ps1
. .\Code\Get-FormatOutput.ps1
. .\Code\Start-ApiServer.ps1
. .\Code\Clear-OldMiners.ps1
. .\Code\Get-ProfitLowerFloor.ps1
. .\Code\DeviceInfo.ps1
. .\Code\Out-DeviceInfo.ps1

function Get-Pool {
	param(
		[Parameter(Mandatory = $true)]
		[string] $algorithm
	)
	$pool = $AllPools | Where-Object -Property Algorithm -eq $algorithm | Select-Object -First 1
	if ($pool) { $pool } else { $null }
}

function Get-Algo {
	param(
		[Parameter(Mandatory = $true)]
		[string] $algorithm
	)
	if ($AllAlgos.Mapping.$algorithm) { $algo = $AllAlgos.Mapping.$algorithm }
	else { $algo = (Get-Culture).TextInfo.ToTitleCase($algorithm) }
	# check asics
	if ($AllAlgos.Disabled -and $AllAlgos.Disabled -contains $algo) { $null }
	# filter by user defined algo
	elseif ((!$AllAlgos.EnabledAlgorithms -or $AllAlgos.EnabledAlgorithms -contains $algo) -and $AllAlgos.DisabledAlgorithms -notcontains $algo) { $algo }
	else { $null }
}

function Set-Stat (
	[Parameter(Mandatory)] [string] $Filename,
	[string] $Key = [string]::Empty,
	[Parameter(Mandatory)] [decimal] $Value,
	[string] $Interval,
	[decimal] $MaxPercent) {
	# fix very high value
	$val = $Statistics.GetValue($Filename, $Key) * [Config]::MaxTrustGrow
	if ($val -gt 0 -and $Value -gt $val) { $Value = $val }
	if ($MaxPercent) {
		$Statistics.SetValue($Filename, $Key, $Value, $Interval, $MaxPercent)
	}
	else {
		$Statistics.SetValue($Filename, $Key, $Value, $Interval)
	}
}

function Remove-Stat (
	[Parameter(Mandatory)] [string] $Filename,
	[Parameter(Mandatory)] [string] $Interval) {
	$Statistics.DelValues($Filename, $Interval);
}

function Get-Question(
	[Parameter(Mandatory)] [string] $Question
) {
	Write-Host "$Question (Yes/No)?: " -NoNewline
	[ConsoleKeyInfo] $y = [Console]::ReadKey($true)
	if ($y.Key -eq [ConsoleKey]::Y) { Write-Host "Yes" -NoNewline -ForegroundColor Green }
	else { Write-Host "No" -NoNewline -ForegroundColor Red }
	Write-Host " Thanks"
	$y.Key -eq [ConsoleKey]::Y
}

function ReadOrCreatePoolConfig(
	[Parameter(Mandatory)] [string] $EnableQuestion,
	[Parameter(Mandatory)] [string] $Filename,
	[Parameter(Mandatory)] $Config) {
	if ([BaseConfig]::Exists($Filename)) {
		$cfg = [BaseConfig]::Read($Filename)
		if ($global:AskPools -eq $true) {
			$cfg.Enabled = (Get-Question $EnableQuestion)
			[BaseConfig]::Save($Filename, $cfg)
		}
		$cfg
	}
	elseif ($global:HasConfirm -eq $true) {
		if (![string]::IsNullOrWhiteSpace($EnableQuestion)) {
			$Config.Enabled = (Get-Question $EnableQuestion)
		}
		[BaseConfig]::ReadOrCreate($Filename, $Config)
	}
	else {
		$global:NeedConfirm = $true
	}
}

function ReadOrCreateConfig(
	[Parameter(Mandatory)] [string] $EnableQuestion,
	[Parameter(Mandatory)] [string] $Filename,
	[Parameter(Mandatory)] $Config) {
	ReadOrCreatePoolConfig $EnableQuestion $Filename $Config
}

function ReadOrCreateMinerConfig(
	[Parameter(Mandatory)] [string] $EnableQuestion,
	[Parameter(Mandatory)] [string] $Filename,
	[Parameter(Mandatory)] $cfg) {
	if ([BaseConfig]::Exists($Filename)) {
		[BaseConfig]::Read($Filename)
	}
	elseif (!$Config.ConfirmMiner) {
		[BaseConfig]::ReadOrCreate($Filename, $cfg)
	}
	elseif ($global:HasConfirm -eq $true) {
		if (![string]::IsNullOrWhiteSpace($EnableQuestion)) {
			$cfg.Enabled = (Get-Question $EnableQuestion)
		}
		[BaseConfig]::ReadOrCreate($Filename, $cfg)
	}
	else {
		$global:NeedConfirm = $true
	}
}

[hashtable] $CCMinerStatsAvg = @{ "Phi" = 1; "Tribus" = 1; "Lyra2re2" = 1; "Lyra2z" = 1; "X17" = 1; "Xevan" = 1 }

function Get-CCMinerStatsAvg (
	[Parameter(Mandatory)] [string] $algo, # Get-Algo
	[Parameter(Mandatory)] $info # AlgoInfo or AlgoInfoEx
) {
	if (!$algo -or !$info) { [ArgumentNullException]::new("Get-CCMinerStatsAvg") }
	[string] $result = [string]::Empty
	if (!$info -or ($info -and (!$info.ExtraArgs -or ($info.ExtraArgs -and !$info.ExtraArgs.Contains("-N "))))) {
		$result = "-N $(if ($CCMinerStatsAvg.$algo) { $CCMinerStatsAvg.$algo } else { 3 })"
	}
	$result
}

function Get-Join(
	[Parameter(Mandatory)] [string] $separator,
	[array] $items
) {
	[string] $result = [string]::Empty
	$items | ForEach-Object {
		if (![string]::IsNullOrWhiteSpace($_)) {
			if (![string]::IsNullOrWhiteSpace($result)) {
				$result += $separator
			}
			$result += $_
		}
	}
	$result
}

function Get-Devices ([Parameter(Mandatory)] [eMinerType[]] $types, $olddevices) {
	Write-Host "Getting devices information ..." -ForegroundColor Green
	$result = [Collections.Generic.Dictionary[eMinerType, Collections.Generic.List[DeviceInfo]]]::new()
	$types | ForEach-Object {
		$type = $_
		switch ($type) {
			([eMinerType]::CPU) {
				if ($olddevices -and $olddevices.$type.Length -gt 0) {
					$result.Add($type, $olddevices.$type)
				}
				else {
					Get-ManagementObject "select * from Win32_Processor" {
						Param([Management.ManagementObjectCollection] $items)
						foreach ($each in $items) {
							$cpu = [CPUInfo]::new()
							foreach ($item in $each.Properties) {
								if ($item.Name -eq "Name") {
									$cpu.Name = ([string]$item.Value).Replace("CPU", [string]::Empty).Replace("(R)", [string]::Empty).Replace("(TM)", [string]::Empty).Replace("  ", " ").Trim()
								}
								elseif ($item.Name -eq "CurrentClockSpeed") {
									$cpu.Clock = [int]::Parse($item.Value)
								}
								elseif ($item.Name -eq "NumberOfCores") {
									$cpu.Cores = [int]::Parse($item.Value)
								}
								elseif ($item.Name -eq "NumberOfLogicalProcessors") {
									$cpu.Threads = [int]::Parse($item.Value)
								}
								# elseif ($item.Name -eq "LoadPercentage") {
								# 	$cpu.Load = [decimal]::Parse($item.Value)
								# }
							}
							$cpu.Features = Get-CPUFeatures ([Config]::BinLocation)
							$result.Add([eMinerType]::CPU, $cpu)
						}
					}
				}
			}
			([eMinerType]::nVidia) {
				# call nVidia smi
				try {
					$path = [IO.Path]::Combine([environment]::GetFolderPath([environment+SpecialFolder]::ProgramFiles), "NVIDIA Corporation\NVSMI", "nvidia-smi.exe")
					$arg = "--query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,clocks.current.graphics,clocks.current.memory,power.default_limit --format=csv,nounits"
					[string] $smi = Get-ProcessOutput $path $arg
					# [string] $smi = "name, utilization.gpu [%], utilization.memory [%], temperature.gpu, power.draw [W], power.limit [W], fan.speed [%], pstate, clocks.current.graphics [MHz], clocks.current.memory [MHz], power.max_limit [W], power.default_limit [W]
					# GeForce GTX 1080 Ti, 98, 5, 50, 211.44, 212.50, 50, P2, 1771, 5005, 300.00, 250.00
					# GeForce GTX 1080 Ti, 98, 5, 50, 212.56, 212.50, 50, P2, 1784, 5005, 300.00, 250.00
					# GeForce GTX 1080 Ti, 98, 5, 51, 214.62, 212.50, 51, P2, 1771, 5005, 300.00, 250.00
					# GeForce GTX 1080 Ti, 98, 5, 55, 213.88, 212.50, 57, P2, 1746, 5005, 300.00, 250.00
					# GeForce GTX 1080 Ti, 98, 5, 52, 218.09, 212.50, 53, P2, 1771, 5005, 300.00, 250.00
					# GeForce GTX 1080 Ti, 97, 5, 52, 208.80, 212.50, 53, P2, 1733, 5005, 300.00, 250.00"
					$bytype = [Collections.Generic.List[DeviceInfo]]::new()
					$header = [Collections.Generic.Dictionary[string, int]]::new()
					$smi.Split([environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
						if ($header.Count -eq 0) {
							$hdr = $_.Split(",");
							for ($i = 0; $i -lt $hdr.Length; $i++) {
								$spl = $hdr[$i].Split(@(" ", "[", "]"), [StringSplitOptions]::RemoveEmptyEntries)
								$header.Add($spl[0], $i);
							}
						}
						else {
							$vals = $_.Replace("GeForce ", [string]::Empty).Split(",")
							$bytype.Add([GPUInfo]@{
								Name = $vals[$header["name"]];
								Load = [MultipleUnit]::ToValueInvariant($vals[$header["utilization.gpu"]], [string]::Empty);
								LoadMem = [MultipleUnit]::ToValueInvariant($vals[$header["utilization.memory"]], [string]::Empty);
								Temperature = [MultipleUnit]::ToValueInvariant($vals[$header["temperature.gpu"]], [string]::Empty);
								Fan = [MultipleUnit]::ToValueInvariant($vals[$header["fan.speed"]], [string]::Empty);
								Power = [decimal]::Round([MultipleUnit]::ToValueInvariant($vals[$header["power.draw"]], [string]::Empty), 1);
								PowerLimit = [decimal]::Round([MultipleUnit]::ToValueInvariant($vals[$header["power.limit"]], [string]::Empty) * 100 / [MultipleUnit]::ToValueInvariant($vals[$header["power.default_limit"]], [string]::Empty));
								Clock = [MultipleUnit]::ToValueInvariant($vals[$header["clocks.current.graphics"]], [string]::Empty);
								ClockMem = [MultipleUnit]::ToValueInvariant($vals[$header["clocks.current.memory"]], [string]::Empty);
							})
						}
					}
					$result.Add([eMinerType]::nVidia, $bytype)
				}
				catch {
					Write-Host "Can't run nvidia-smi.exe: $_" -ForegroundColor Red
					Start-Sleep -Seconds ($Config.CheckTimeout)
				}
			}
			default {}
		}
	}
	return $result
}