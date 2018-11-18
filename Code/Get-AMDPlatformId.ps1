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

function Get-AMDPlatformId([Parameter(Mandatory)][PSCustomObject] $json) {
	[int] $result = -1
	$json | ForEach-Object {
		if ($_.PlatformName.ToLowerInvariant().Contains("amd")) {
			$result = $_.PlatformNum
		}
	}
	if ($result -eq -1) {
		Write-Host "Can't detect AMD Platform ID." -ForegroundColor Red
	}
	$result
}

function Get-CudaVersion([Parameter(Mandatory)][PSCustomObject] $json) {
	# https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/index.html
	[version] $result = [version]::new()
	$json | ForEach-Object {
		if ($_.PlatformName.ToLowerInvariant().Contains("nvidia")) {
			$_.Devices | ForEach-Object {
				$ver = [version]::new($_._CL_DRIVER_VERSION)
				if ($ver -ge [version]::new(411, 31)) {
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
			}
		}
	}
	if ($result -eq [version]::new()) {
		Write-Host "Can't detect Cuda version." -ForegroundColor Red
	}
	$result
}