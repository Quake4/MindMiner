<#
MindMiner  Copyright (C) 2017-2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-OpenCLDeviceDetection ([Parameter(Mandatory)][string] $bin) {
	try {
		[string] $line = Get-ProcessOutput ([IO.Path]::Combine($bin, "AMDOpenCLDeviceDetection.exe"))
		return $line | ConvertFrom-Json
	}
	catch {
		Write-Host "Can't run AMDOpenCLDeviceDetection.exe: $_" -ForegroundColor Red
	}
}

function Get-AMDPlatformId([PSCustomObject] $json) {
	[int] $result = -1
	if ($json) {
		$json | ForEach-Object {
			if ($_.PlatformName.ToLowerInvariant().Contains("amd")) {
				$result = $_.PlatformNum
			}
		}
	}
	if ($result -eq -1) {
		Write-Host "Can't detect AMD Platform ID." -ForegroundColor Red
		Start-Sleep -Seconds ($Config.CheckTimeout)
	}
	$result
}

function ParseCudaVersion([Parameter(Mandatory)][string] $verstr) {
	$ver = [version]::new($verstr)
	# https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html
	$result = [version]::new()
	if ($ver -ge [version]::new(418, 96)) {
		$result = [version]::new(10, 1);
	}
	elseif ($ver -ge [version]::new(411, 31)) {
		$result = [version]::new(10, 0);
	}
	elseif ($ver -ge [version]::new(397, 44)) {
		$result = [version]::new(9, 2);
	}
	elseif ($ver -ge [version]::new(391, 29)) {
		$result = [version]::new(9, 1);
	}
	elseif ($ver -ge [version]::new(385, 54)) {
		$result = [version]::new(9, 0);
	}
	$result
}

function Get-CudaVersion([PSCustomObject] $json) {
	[version] $result = [version]::new()
	if ($json) {
		$json | ForEach-Object {
			if ($_.PlatformName.ToLowerInvariant().Contains("nvidia")) {
				$_.Devices | ForEach-Object {
					if ($result -eq [version]::new()) {
						$result = ParseCudaVersion ($_._CL_DRIVER_VERSION)
					}
				}
			}
		}
	}
	# if variant one not working
	if ($result -eq [version]::new()) {
		[string] $smi = Get-SMIInfo "--query-gpu=driver_version --format=csv,nounits,noheader"
		if ($smi) {
			$smi.Split([environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
				if ($result -eq [version]::new()) {
					$result = ParseCudaVersion $_ 
				}
			}
		}
	}
	if ($result -eq [version]::new()) {
		Write-Host "Can't detect Cuda version." -ForegroundColor Red
		Start-Sleep -Seconds ($Config.CheckTimeout)
	}
	$result
}

function Get-SMIInfo ([Parameter(Mandatory)][string] $arg) {
	try {
		return Get-ProcessOutput ([Config]::SMIPath) $arg
	}
	catch {
		Write-Host "Can't run nvidia-smi.exe: $_" -ForegroundColor Red
	}
}

function Get-OverdriveN ([Parameter(Mandatory)][string] $bin) {
	try {
		[string] $lines = Get-ProcessOutput ([IO.Path]::Combine($bin, "OverdriveN.exe"))
		if ([string]::IsNullOrWhiteSpace($lines)) {
			throw [Exception]::new("Empty answer")
		}
		return $lines
	}
	catch {
		Write-Host "Can't run OverdriveN: $_" -ForegroundColor Red
		Start-Sleep -Seconds ($Config.CheckTimeout)
	}
}

function Get-Devices ([Parameter(Mandatory)] [eMinerType[]] $types, $olddevices) {
	Write-Host "Retrieve devices status ..." -ForegroundColor Green
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
									$cpu.Name = ([string]$item.Value).Replace("CPU", [string]::Empty).Replace("(R)", [string]::Empty).Replace("(TM)", [string]::Empty).Replace("Processor", [string]::Empty).Replace("  ", " ").Trim()
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
								elseif ($item.Name -eq "LoadPercentage") {
								 	$cpu.Load = [decimal]::Parse($item.Value)
								}
							}
							$cpu.Features = Get-CPUFeatures ([Config]::BinLocation)
							$result.Add([eMinerType]::CPU, $cpu)
						}
					}
				}
				try {
					if ($global:Admin) {
						if (!$global:OHMPC) {
							[Reflection.Assembly]::LoadFile([IO.Path]::Combine($BinLocation, "OpenHardwareMonitorLib.dll")) | Out-Null
							$global:OHMPC = [OpenHardwareMonitor.Hardware.Computer]::new()
							$global:OHMPC.CPUEnabled = $true
							$global:OHMPC.Open()
						}
						$i = 0;
						foreach ($hw in $global:OHMPC.Hardware) {
							if ($hw.HardwareType -eq "CPU") {
								$hw.Update()
								$result["CPU"][$i].Power = 0
								foreach ($sens in $hw.Sensors) {
									if ($sens.SensorType -match "temperature" -and $sens.Name -match "package") {
										$result["CPU"][$i].Temperature = [decimal]$sens.Value
									}
									elseif ($sens.SensorType -match "power" -and $sens.Name -match "package") {
										$result["CPU"][$i].Power += [decimal]$sens.Value
									}
									elseif ($sens.SensorType -match "power" -and $sens.Name -match "cores") {
										$result["CPU"][$i].Power += [decimal]$sens.Value
									}
								}
								$result["CPU"][$i].Power = [decimal]::Round($result["CPU"][$i].Power, 1);
								$i++
							}
						}
					}
					else {
						if (!$global:CPUWarn) {
							Write-Host "Can't get CPU temperature and power consumption due access restrictions. To resolve this, run MindMiner as Administrator" -ForegroundColor Yellow
							Start-Sleep -Seconds ($Config.CheckTimeout)
							$global:CPUWarn = $true
						}
					}
				}
				catch {
					Write-Host "Can't get CPU temperature and power consumption: $_" -ForegroundColor Red
					Start-Sleep -Seconds ($Config.CheckTimeout)
				}
			}
			([eMinerType]::nVidia) {
				# call nVidia smi
				try {
					[string] $smi = Get-SMIInfo "--query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,clocks.current.graphics,clocks.current.memory,power.default_limit --format=csv,nounits"
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
							$vals = $_.Replace("GeForce ", [string]::Empty).Replace("[Not Supported]", "0").Replace("[Unknown Error]", "0").Split(",")
							$gpuinfo = [GPUInfo]@{
								Name = $vals[$header["name"]];
								Load = [MultipleUnit]::ToValueInvariant($vals[$header["utilization.gpu"]], [string]::Empty);
								LoadMem = [MultipleUnit]::ToValueInvariant($vals[$header["utilization.memory"]], [string]::Empty);
								Temperature = [MultipleUnit]::ToValueInvariant($vals[$header["temperature.gpu"]], [string]::Empty);
								Fan = [MultipleUnit]::ToValueInvariant($vals[$header["fan.speed"]], [string]::Empty);
								Power = [decimal]::Round([MultipleUnit]::ToValueInvariant($vals[$header["power.draw"]], [string]::Empty), 1);
								PowerLimit = [decimal]::Round([MultipleUnit]::ToValueInvariant($vals[$header["power.limit"]], [string]::Empty) * 100 / [MultipleUnit]::ToValueInvariant($vals[$header["power.default_limit"]], [string]::Empty));
								Clock = [MultipleUnit]::ToValueInvariant($vals[$header["clocks.current.graphics"]], [string]::Empty);
								ClockMem = [MultipleUnit]::ToValueInvariant($vals[$header["clocks.current.memory"]], [string]::Empty);
							}
							$gpuinfo.CalcPower();
							$bytype.Add($gpuinfo);
						}
					}
					$result.Add([eMinerType]::nVidia, $bytype)
				}
				catch {
					Write-Host "Can't run nvidia-smi.exe: $_" -ForegroundColor Red
					Start-Sleep -Seconds ($Config.CheckTimeout)
				}
			}
			([eMinerType]::AMD) {
				[string] $info = Get-OverdriveN ([Config]::BinLocation)
				# $info = "0,2750,3300,111769,175000,100,71000,0,Radeon RX 560 Series,PCI_VEN_1002&DEV_67FF&SUBSYS_2381148C&REV_CF_4&BAB4994&0&0008A"
				$bytype = [Collections.Generic.List[DeviceInfo]]::new()
				$info.split([environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | Where-Object { $_ -notlike "*&???" -and $_ -notmatch ".*failed" } | ForEach-Object {
					$vals = $_.Replace("Radeon", [string]::Empty).Replace("AMD", [string]::Empty).Replace("Series", [string]::Empty).Replace("(TM)", [string]::Empty).Replace("Graphics", [string]::Empty).Split(",")
					$gpuinfo = [GPUInfo]@{
						Name = $vals[8].Trim();
						Load = [decimal]$vals[5];
						# LoadMem = [MultipleUnit]::ToValueInvariant($vals[$header["utilization.memory"]], [string]::Empty);
						Temperature = [decimal]$vals[6] / 1000;
						Fan = [decimal]::Round([decimal]$vals[1] * 100 / [decimal]$vals[2]);
						# Power -- CalcPower
						PowerLimit = 100 + [decimal]$vals[7];
						Clock =  [decimal]::Round([decimal]$vals[3] / 100);
						ClockMem = [decimal]::Round([decimal]$vals[4] / 100);
					}
					$gpuinfo.CalcPower();
					$bytype.Add($gpuinfo);
				}
				$result.Add([eMinerType]::AMD, $bytype)
			}
			default {}
		}
	}
	return $result
}