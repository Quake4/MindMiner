<#
MindMiner  Copyright (C) 2017-2021  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

function Get-OpenCLDeviceDetection ([Parameter(Mandatory)][string] $bin, [int] $timeout) {
	try {
		[string] $line = Get-ProcessOutput ([IO.Path]::Combine($bin, "AMDOpenCLDeviceDetection.exe"))
		return $line | ConvertFrom-Json
	}
	catch {
		Write-Host "Can't run AMDOpenCLDeviceDetection.exe: $_" -ForegroundColor Red
		Start-Sleep -Seconds $timeout
	}
}

function Get-PlatformId([PSCustomObject] $json, [string] $key, [int] $timeout) {
	[int] $result = -1
	if ($json) {
		$json | ForEach-Object {
			if ($_.PlatformName.ToLowerInvariant().Contains($key.ToLowerInvariant())) {
				$result = $_.PlatformNum
			}
		}
	}
	if ($result -eq -1) {
		Write-Host "Can't detect $key Platform ID." -ForegroundColor Red
		Start-Sleep -Seconds $timeout
	}
	$result
}

function ParseCudaVersion([Parameter(Mandatory)][string] $verstr) {
	$ver = [version]::new($verstr)
	# https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html
	$result = [version]::new()
	if ($ver -ge [version]::new(471, 11)) {
		$result = [version]::new(11, 4);
	}
	elseif ($ver -ge [version]::new(465, 89)) {
		$result = [version]::new(11, 3);
	}
	elseif ($ver -ge [version]::new(460, 82)) {
		$result = [version]::new(11, 2);
	}
	elseif ($ver -ge [version]::new(456, 38)) {
		$result = [version]::new(11, 1);
	}
	elseif ($ver -ge [version]::new(451, 48)) {
		$result = [version]::new(11, 0);
	}
	elseif ($ver -ge [version]::new(441, 22)) {
		$result = [version]::new(10, 2);
	}
	elseif ($ver -ge [version]::new(418, 96)) {
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

function Get-CudaVersion([PSCustomObject] $json, [int] $timeout) {
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
		Start-Sleep -Seconds $timeout
	}
	$result
}

function Get-CudaDevices([PSCustomObject] $json, [int] $timeout) {
	[int] $result = 0
	if ($json) {
		$json | ForEach-Object {
			if ($_.PlatformName.ToLowerInvariant().Contains("nvidia")) {
				$_.Devices | ForEach-Object {
					$result++;
				}
			}
		}
	}
	# if variant one not working
	if ($result -eq 0) {
		[string] $smi = Get-SMIInfo "--query-gpu=driver_version --format=csv,nounits,noheader" #memory.total
		if ($smi) {
			$smi.Split([environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
				$result++;
			}
		}
	}
	if ($result -eq 0) {
		Write-Host "Can't detect Cuda devices count." -ForegroundColor Red
		Start-Sleep -Seconds $timeout
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
						$list = [Collections.Generic.List[DeviceInfo]]::new()
						foreach ($each in $items) {
							$cpu = [CPUInfo]::new()
							foreach ($item in $each.Properties) {
								if ($item.Name -eq "Name") {
									$cpu.Name = (([string]$item.Value).Replace("CPU", [string]::Empty).Replace("(R)", [string]::Empty).Replace("(TM)", [string]::Empty).Replace("(tm)", [string]::Empty).Replace("Processor", [string]::Empty).Replace("  ", " ") -replace "(\d+|\w+)-Core", [string]::Empty).Trim()
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
							$list.Add($cpu)
						}
						$result.Add([eMinerType]::CPU, $list)
					}
				}
				try {
					if ($global:Admin) {
						if (!$global:OHMPC) {
							[Reflection.Assembly]::LoadFile([IO.Path]::Combine($BinLocation, "OpenHardwareMonitorLib.dll")) | Out-Null
							$global:OHMPC = [OpenHardwareMonitor.Hardware.Computer]::new()
							$global:OHMPC.CPUEnabled = $true
							if ($types -contains [eMinerType]::AMD) {
								$global:OHMPC.GPUEnabled = $true
							}							
							$global:OHMPC.Open()
						}
						$i = 0;
						foreach ($hw in $global:OHMPC.Hardware) {
							if ($hw.HardwareType -eq "CPU") {
								$hw.Update()
								$result["CPU"][$i].Power = 0
								[decimal] $tempbycore = 0
								[decimal] $powerbycore = 0
								foreach ($sens in $hw.Sensors) {
									if ($sens.SensorType -match "temperature" -and $sens.Name -match "package") {
										$result["CPU"][$i].Temperature = [decimal]$sens.Value
									}
									elseif ($sens.SensorType -match "temperature" -and $sens.Name -match "core") {
										$tempbycore = [Math]::Max($tempbycore, [decimal]$sens.Value)
									}
									elseif ($sens.SensorType -match "power" -and $sens.Name -match "package") {
										$result["CPU"][$i].Power += [decimal]$sens.Value
									}
									elseif ($sens.SensorType -match "power" -and $sens.Name -match "cores") {
										$powerbycore += [decimal]$sens.Value
									}
									elseif ($sens.SensorType -match "load" -and $sens.Name -match "total") {
										$result["CPU"][$i].Load = [decimal]::Round([decimal]$sens.Value, 1);
									}
								}
								if ($result["CPU"][$i].Power -eq 0 -or $result["CPU"][$i].Power -lt $powerbycore) {
									$result["CPU"][$i].Power = $powerbycore
								}
								$result["CPU"][$i].Power = [decimal]::Round($result["CPU"][$i].Power, 1);
								if ($result["CPU"][$i].Temperature -eq 0) {
									$result["CPU"][$i].Temperature = $tempbycore
								}
								$result["CPU"][$i].Temperature = [decimal]::Round($result["CPU"][$i].Temperature, 0);
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
							$vals = $_.Replace("[Not Supported]", "0").Replace("[N/A]", "0").Replace("[Unknown Error]", "0").Split(",")
							$dpl = [MultipleUnit]::ToValueInvariant($vals[$header["power.default_limit"]], [string]::Empty)
							if ($dpl -eq 0) { $dpl = 100 }
							$gpuinfo = [GPUInfo]@{
								Name = $vals[$header["name"]].Replace("nVidia ", [string]::Empty).Replace("NVIDIA ", [string]::Empty).Replace("GeForce ", [string]::Empty);
								Load = [MultipleUnit]::ToValueInvariant($vals[$header["utilization.gpu"]], [string]::Empty);
								LoadMem = [MultipleUnit]::ToValueInvariant($vals[$header["utilization.memory"]], [string]::Empty);
								Temperature = [MultipleUnit]::ToValueInvariant($vals[$header["temperature.gpu"]], [string]::Empty);
								Fan = [MultipleUnit]::ToValueInvariant($vals[$header["fan.speed"]], [string]::Empty);
								Power = [decimal]::Round([MultipleUnit]::ToValueInvariant($vals[$header["power.draw"]], [string]::Empty), 1);
								PowerLimit = [decimal]::Round([MultipleUnit]::ToValueInvariant($vals[$header["power.limit"]], [string]::Empty) * 100 / $dpl);
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
					Write-Host "Can't parse nvidia-smi GPU status result: $_" -ForegroundColor Red
					Start-Sleep -Seconds ($Config.CheckTimeout)
				}
			}
			([eMinerType]::AMD) {
				try {
					if (!$global:OHMPC) {
						[Reflection.Assembly]::LoadFile([IO.Path]::Combine($BinLocation, "OpenHardwareMonitorLib.dll")) | Out-Null
						$global:OHMPC = [OpenHardwareMonitor.Hardware.Computer]::new()
						$global:OHMPC.GPUEnabled = $true
						$global:OHMPC.Open()
					}
					$bytype = [Collections.Generic.List[DeviceInfo]]::new()
					foreach ($hw in $global:OHMPC.Hardware) {
						if ($hw.HardwareType -eq "GpuAti") {
							$hw.Update()
							# "$($hw | ConvertTo-Json)" | Out-File "1.txt"
							$gpuinfo = [GPUInfo]@{
								Name = $hw.Name.Replace("Radeon", [string]::Empty).Replace("AMD", [string]::Empty).Replace("Series", [string]::Empty).Replace("(TM)", [string]::Empty).Replace("Graphics", [string]::Empty).Trim();
							}
							foreach ($sens in $hw.Sensors) {
								# Write-Host "$($sens.Name) ($($sens.SensorType)): $($sens.Value)"
								if ($sens.SensorType -match "load" -and $sens.Name -match "core") {
									$gpuinfo.Load = [MultipleUnit]::ToValueInvariant($sens.Value, [string]::Empty);
								}
								elseif ($sens.SensorType -match "load" -and $sens.Name -match "memory") {
									$gpuinfo.LoadMem = [MultipleUnit]::ToValueInvariant($sens.Value, [string]::Empty);
								}
								elseif ($sens.SensorType -match "temperature" -and $sens.Name -match "core") {
									$gpuinfo.Temperature = [MultipleUnit]::ToValueInvariant($sens.Value, [string]::Empty);
								}
								elseif ($sens.SensorType -match "control" -and $sens.Name -match "fan") {
									$gpuinfo.Fan = [MultipleUnit]::ToValueInvariant($sens.Value, [string]::Empty);
								}
								elseif ($sens.SensorType -match "power" -and $sens.Name -match "total") {
									$gpuinfo.Power = [decimal]::Round([MultipleUnit]::ToValueInvariant($sens.Value, [string]::Empty), 1);
								}
								elseif ($sens.SensorType -match "clock" -and $sens.Name -match "core") {
									$gpuinfo.Clock = [decimal]::Round([MultipleUnit]::ToValueInvariant($sens.Value, [string]::Empty));
								}
								elseif ($sens.SensorType -match "clock" -and $sens.Name -match "memory") {
									$gpuinfo.ClockMem = [decimal]::Round([MultipleUnit]::ToValueInvariant($sens.Value, [string]::Empty));
								}
							}
							$gpuinfo.CalcPower();
							$bytype.Add($gpuinfo);
						}
					}
					$result.Add([eMinerType]::AMD, $bytype)
				}
				catch {
					Write-Host "Can't get AMD GPU temperature and power consumption: $_" -ForegroundColor Red
					Start-Sleep -Seconds ($Config.CheckTimeout)
				}
			}
			default {}
		}
	}
	return $result
}