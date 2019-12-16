<#
MindMiner  Copyright (C) 2017-2019  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

class AlgoInfo {
	[bool] $Enabled
	[string] $Algorithm

	[string] ToString() {
		return $this | Select-Object Enabled, Algorithm
	}
}

class AlgoInfoEx : AlgoInfo {
	[string] $ExtraArgs
	[int] $BenchmarkSeconds
	
	[string] ToString() {
		return $this | Select-Object Enabled, Algorithm, ExtraArgs, BenchmarkSeconds
	}
}

class SpeedProfitItemInfo {
	[decimal] $Speed
	[decimal] $Profit

	SpeedProfitItemInfo([decimal] $speed, [decimal] $profit) {
		$this.Speed = $speed
		$this.Profit = $profit
	}
}

class SpeedProfitInfo {
	[SpeedProfitItemInfo] $Item
	[SpeedProfitItemInfo] $Mrr

	[void] SetValue([decimal] $speed, [decimal] $profit, [bool] $mrr) {
		if ($mrr) {
			if (!$this.Mrr -or $this.Mrr.Profit -lt $profit) {
				$this.Mrr = [SpeedProfitItemInfo]::new($speed, $profit)
			}
		}
		else {
			if (!$this.Item -or $this.Item.Profit -lt $profit) {
				$this.Item = [SpeedProfitItemInfo]::new($speed, $profit)
			}
		}
	}

	# [SpeedProfitItemInfo] Get([bool] $mrr) {
	# 	return if ($mrr) { $this.Mrr } else { $this.Item }
	# }
}