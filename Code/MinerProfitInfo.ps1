<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\MinerInfo.ps1

class MinerProfitInfo {
	[MinerInfo] $Miner
	[decimal] $Speed
	[decimal] $Price
	[decimal] $Profit
	[decimal] $DualSpeed
	[decimal] $DualPrice

	MinerProfitInfo([MinerInfo] $miner, [decimal] $speed, [decimal] $price) {
		$this.Miner = $miner
		$this.Price = $price
		$this.SetSpeed($speed)
	}

	MinerProfitInfo([MinerInfo] $miner, [decimal] $speed, [decimal] $price, [decimal] $dualspeed, [decimal] $dualprice) {
		$this.Miner = $miner
		$this.Price = $price
		$this.DualPrice = $dualprice
		$this.SetSpeed($speed, $dualspeed)
	}
	
	[void] SetSpeed([decimal] $speed) {
		$this.Speed = $speed
		$this.Profit = $this.Price * $speed
	}

	[void] SetSpeed([decimal] $speed, [decimal] $dualspeed) {
		$this.Speed = $speed
		$this.DualSpeed = $dualspeed
		$this.Profit = $this.Price * $speed + $this.DualPrice * $dualspeed
	}
}