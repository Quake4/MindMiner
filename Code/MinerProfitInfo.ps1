<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Config.ps1
. .\Code\MinerInfo.ps1

class MinerProfitInfo {
	[MinerInfo] $Miner
	[decimal] $Speed
	[decimal] $Price
	[decimal] $Profit

	MinerProfitInfo([MinerInfo] $miner, [Config] $config,  [decimal] $speed, [decimal] $price) {
		$this.Miner = [MinerInfo](($miner | ConvertTo-Json).Replace([Config]::WorkerNamePlaceholder, $config.WorkerName) | ConvertFrom-Json)
		$this.Price = $price
		$this.SetSpeed($speed)
	}

	[void] SetSpeed([decimal] $speed) {
		$this.Speed = $speed
		$this.Profit = $this.Price * $speed
	}
}