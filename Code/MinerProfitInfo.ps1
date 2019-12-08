<#
MindMiner  Copyright (C) 2017  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

. .\Code\Config.ps1
. .\Code\MinerInfo.ps1

class MinerProfitInfo {
	[MinerInfo] $Miner
	[bool] $SwitchingResistance
	[decimal] $Speed
	[decimal] $Price
	[decimal] $Profit
	[decimal] $ProfitRaw
	[decimal] $DualSpeed
	[decimal] $DualPrice
	[decimal] $Power
	[decimal] $PowerDraw
	[decimal] $PowerPrice
	[bool] $AccountPower

	MinerProfitInfo([MinerInfo] $miner, [Config] $config, [decimal] $speed, [decimal] $price) {
		$this.Miner = [MinerInfo]($miner | ConvertTo-Json | ConvertFrom-Json)
		$this.Price = $price
		$this.AccountPower = $config.ElectricityConsumption
		$this.SetSpeed($speed)
	}

	MinerProfitInfo([MinerInfo] $miner, [Config] $config, [decimal] $speed, [decimal] $price, [decimal] $dualspeed, [decimal] $dualprice) {
		$this.Miner = [MinerInfo]($miner | ConvertTo-Json | ConvertFrom-Json)
		$this.Price = $price
		$this.DualPrice = $dualprice
		$this.AccountPower = $config.ElectricityConsumption
		$this.SetSpeed($speed, $dualspeed)
	}
	
	[void] SetSpeed([decimal] $speed) {
		$this.Speed = $speed
		$this.ProfitRaw = $this.Profit = $this.Price * $speed
	}

	[void] SetSpeed([decimal] $speed, [decimal] $dualspeed) {
		$this.Speed = $speed
		$this.DualSpeed = $dualspeed
		$this.ProfitRaw = $this.Profit = $this.Price * $speed + $this.DualPrice * $dualspeed
	}

	[void] SetPower([decimal] $draw, [decimal] $price) {
		$this.PowerDraw = $draw
		$this.PowerPrice = $price
		$this.Power = $price * $draw * 24 / 1024
		if ($this.AccountPower) {
			$this.Profit = $this.ProfitRaw - $this.Power;
		}
	}

	static [MinerInfo] CopyMinerInfo([MinerInfo] $miner, [Config] $config) {
		[string] $json = ($miner | ConvertTo-Json).Replace([Config]::WorkerNamePlaceholder, $config.WorkerName).Replace([Config]::LoginPlaceholder, $config.Login)
		$config.Wallet | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			$json = $json.Replace(([Config]::WalletPlaceholder -f "$_"), $config.Wallet.$_)
		}
		return [MinerInfo]($json | ConvertFrom-Json)
	}
}