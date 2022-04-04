<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Cfg = [BaseConfig]::ReadOrCreate([IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + [BaseConfig]::Filename), @{
	Enabled = $false
	ProxyList = $null
})
if (!$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
[Config]::UseApiProxy = $PoolInfo.Enabled
if (!$Cfg.Enabled) { return $null }

$currentfilename = [IO.Path]::Combine($PSScriptRoot, $PoolInfo.Name + ".current.txt")
$Current = [BaseConfig]::ReadOrCreate($currentfilename, @{
	Proxy = $null
})

$proxylist = [Collections.Generic.List[uri]]::new()
if (![string]::IsNullOrWhiteSpace($Current.Proxy)) {
	$proxylist.Add((Get-ProxyAddress $Current.Proxy))
}
$Cfg.ProxyList | ForEach-Object {
	if (![string]::IsNullOrWhiteSpace($_)) {
		$proxylist.Add((Get-ProxyAddress $_))
	}
}

$proxylist | ForEach-Object {
	if (!$PoolInfo.HasAnswer) {
		try {
			$RequestWallets = Get-Rest "$_`wallets"
			if ($RequestWallets)
			{
				if ($RequestWallets.Wallet) {
					$Config.Wallet = $RequestWallets.Wallet
				}
				if ($RequestWallets.Login) {
					$Config.Login = $RequestWallets.Login
				}
				if ($RequestWallets.Password) {
					$Config.Password = $RequestWallets.Password
				}
				if ($RequestWallets.ApiKey) {
					$Config.ApiKey = $RequestWallets.ApiKey
				}
				if ($RequestWallets.Service) {
					$Config.Service = $RequestWallets.Service
				}
				$Config.Region = $RequestWallets.Region
			}
			$RequestPools = Get-Rest "$_`pools"
			if ($RequestPools) {
				$PoolInfo.HasAnswer = $true
				$PoolInfo.AnswerTime = [DateTime]::Now
				$PoolInfo.AverageProfit = $_.Host

				# before full move to new version
				try {
					$RequestAlgs = Get-Rest "$_`poolalglist"
					if ($RequestAlgs) {
						$RequestAlgs | ForEach-Object {
							$alg = $_
							$alg.Extra = $null
							$PoolInfo.Algorithms.Add([PoolAlgorithmInfo]$alg)
						}
					}
				}
				catch {
					Write-Host "The new version of API is not available, getting the old one." -ForegroundColor Yellow
				}

				if ($PoolInfo.Algorithms.Length -eq 0) {
					$RequestPools | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
						$pool = $RequestPools.$_
						# now no data from master
						$pool.Extra = $null
						<#if ($pool.Extra -ne $null) {
							$hash = [hashtable]::new()
							$pool.Extra | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
								$hash[$_] = $pool.Extra.$_
							}
							$pool.Extra = $hash
						}#>
						$PoolInfo.Algorithms.Add([PoolAlgorithmInfo]$pool)
					}
				}
				
				if ($Current.Proxy -ne $_.Host) {
					$Current.Proxy = $_.Host
					$Current | ConvertTo-Json | Out-File -FilePath $currentfilename -Force
				}
			}
			$global:MRRPoolData = Get-Rest "$_`mrrpool"
		}
		catch
		{
			Write-Host "$($PoolInfo.Name) error: $_" -ForegroundColor Red
			Start-Sleep -Seconds ($Config.CheckTimeout)
		}
	}
}

$PoolInfo