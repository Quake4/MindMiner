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
			"Vega 64" { $pwr = 295 }
			"Vega 56" { $pwr = 210 }
			"RX 590" { $pwr = 225 }
			"RX 580" { $pwr = 185 }
			"RX 480" { $pwr = 185 }
			"RX 570" { $pwr = 150 }
			"RX 470" { $pwr = 120 }
			"RX 560" { $pwr = 80 }
			"RX 460" { $pwr = 70 }
			"RX 550" { $pwr = 50 }
			Default {}
		}
		$this.Power = $this.PowerLimit * $pwr * $this.Load / 10000;
		if ($this.Power -eq 0) {
			$this.Power = $pwr / 10;
		}
	}
}