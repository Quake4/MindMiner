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

	MinerProfitInfo([MinerInfo] $miner, [decimal] $speed, [decimal] $price) {
		$this.Miner = $miner
		$this.Price = $price
		$this.SetSpeed($speed)
	}

	[void] SetSpeed([decimal] $speed) {
		$this.Speed = $speed
		$this.Profit = $this.Price * $speed
	}
}