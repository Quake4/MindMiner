<#
MindMiner  Copyright (C) 2018  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class DeviceInfo {
	[string] $Name
}

class CPUInfo : DeviceInfo {
	[int] $Cores
	[int] $Threads
	[int] $Clock
	[string] $Features
	# [decimal] $Load
}

class GPUInfo : DeviceInfo {
	[decimal] $Load
	[decimal] $LoadMem
	[decimal] $Temperature
	[decimal] $Fan
	[decimal] $Power
	[decimal] $PowerLimit
	[decimal] $Clock
	[decimal] $ClockMem

	[void] CalcPower() {
		[int] $pwr = 0
		switch ($this.Name) {
			"Vega 64" { $pwr = 230 }
			"Vega 56" { $pwr = 210 }
			"RX 580" { $pwr = 135 }
			"RX 480" { $pwr = 135 }
			"RX 570" { $pwr = 120 }
			"RX 470" { $pwr = 120 }
			"RX 560" { $pwr = 75 }
			"RX 460" { $pwr = 75 }
			Default {}
		}
		$this.Power = $this.PowerLimit * $pwr * $this.Load / 10000;
		if ($this.Power -eq 0) {
			$this.Power = $pwr / 10;
		}
	}
}