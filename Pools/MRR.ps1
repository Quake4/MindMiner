<#
MindMiner  Copyright (C) 2018-2022  Oleg Samsonov aka Quake4
https://github.com/Quake4/MindMiner
License GPL-3.0
#>

$PoolInfo = [PoolInfo]::new()
$PoolInfo.Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$configfile = $PoolInfo.Name + [BaseConfig]::Filename
$configpath = [IO.Path]::Combine($PSScriptRoot, $configfile)

$Cfg = ReadOrCreatePoolConfig "Do you want to pass a rig to rent on $($PoolInfo.Name) (1% extra fee)" $configpath @{
	Enabled = $false
	Key = $null
	Secret = $null
	Region = $null
	FailoverRegion = $null
	DisabledAlgorithms = $null
	Wallets = $null
	Target = 50
	Increase = 5
	Decrease = 1
	MinHours = 4
	MaxHours = 12
	DisabledRenters = $null
}

if (($global:AskPools -or $global:HasConfirm) -and $Cfg -and $Cfg.Enabled -and [string]::IsNullOrWhiteSpace($Cfg.Key) -and [string]::IsNullOrWhiteSpace($Cfg.Secret)) {
	Write-Host "Create Api Key on `"https://www.miningrigrentals.com/account/apikey`" with grant to `"Manage Rigs`" as `"Yes`"." -ForegroundColor Yellow
	$Cfg.Key = Read-Host "Enter `"Key`""
	$Cfg.Secret = Read-Host "Enter `"Secret`""
	# ask wallets
	$Cfg.Wallets = $null
	[Config]::MRRWallets | ForEach-Object {
		if (Get-Question "Do you want to accept payment in '$($_.ToUpper())'") {
			if (!$Cfg.Wallets) { $Cfg.Wallets = @() }
			$Cfg.Wallets += "$_"
		}
	}
	# save config
	[BaseConfig]::Save($configpath, $Cfg)
}

if ($global:AskPools -eq $true -or !$Cfg) { return $null }

$PoolInfo.Enabled = $Cfg.Enabled
if (!$Cfg.Enabled) {
	$global:MRRRentedTypes = @()
	return $PoolInfo
}
if (!$Cfg.DisabledAlgorithms) { $Cfg.DisabledAlgorithms = @() }

if ([string]::IsNullOrWhiteSpace($Cfg.Key) -or [string]::IsNullOrWhiteSpace($Cfg.Secret)) {
	Write-Host "Fill in the `"Key`" and `"Secret`" parameters in the configuration file `"$configfile`" or disable the $($PoolInfo.Name)." -ForegroundColor Yellow
	return $PoolInfo
}

$server = $null
$failoverserver = $null
$algs = [Collections.Generic.Dictionary[string, PoolAlgorithmInfo]]::new()

# or from remote or local
if ([Config]::UseApiProxy -and $global:MRRPoolData) {
	$server = $global:MRRPoolData.Server
	$failoverserver = $global:MRRPoolData.FailoverServer
	$global:MRRPoolData.Algos | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
		$alg = $global:MRRPoolData.Algos.$_
		[hashtable]$ht = @{}
		$alg.Extra | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object { $ht[$_] = $alg.Extra.$_ }
		$alg.Extra = $ht
		# $alg.Priority = [Priority]::None
		$algs.Add($_, [PoolAlgorithmInfo]$alg)
	}
	Write-Host "MRR: Server and failoverserver are received from Master."
}
else {
	$servers_req = Get-Rest "https://www.miningrigrentals.com/api/v2/info/servers"
	if (!$servers_req -or !$servers_req.success) {
		return $PoolInfo
	}

	$servers = $servers_req.data | Sort-Object -Property name

	$region = $Cfg.Region
	if ([string]::IsNullOrWhiteSpace($region)) {
		$region = "us"
		switch ($Config.Region) {
			"$([eRegion]::Europe)" { $region = "eu" }
			"$([eRegion]::China)" { $region = "ap" }
			"$([eRegion]::Japan)" { $region = "jp" }
		}
		if ($region -eq "eu") {
			[string] $locale = "$($region)-$((Get-Host).CurrentCulture.TwoLetterISOLanguageName)"
			if ($servers | Where-Object { $_.region -match $locale }) {
				$region = $locale
			}
		}
	}
	$server = $servers | Where-Object { $_.region -match $region -or $_.name -match "^$region\." } | Sort-Object name | Select-Object -First 1

	if (!$server -or $server.Length -gt 1) {
		Write-Host "Set `"Region`" parameter from list ($(Get-Join ", " $($servers | Select-Object -ExpandProperty region | Get-Unique))) in the configuration file `"$configfile`" or set 'null' value." -ForegroundColor Yellow
		return $PoolInfo;
	}

	$failoverserver = $servers | Where-Object { ($_.region -match $Cfg.FailoverRegion -or $_.name -match "^$($Cfg.FailoverRegion)\." -or (!$Cfg.FailoverRegion -and $_.region -match $region)) -and $_.region -ne $server.region } |
		Sort-Object name | Select-Object -First 1
	if ($null -eq $failoverserver) {
		Write-Host "Set `"FailoverRegion`" parameter from list ($(Get-Join ", " $($servers | Where-Object { $_.region -ne $server.region } | Select-Object -ExpandProperty region | Get-Unique))) in the configuration file `"$configfile`"." -ForegroundColor Yellow
		$failoverserver = $servers | Where-Object { $_.region -ne $server.region } | Select-Object -First 1
	}
	# Write-Host "Servers: $($server.name) + $($failoverserver.name)"

	# check algorithms
	$AlgosRequest = Get-Rest "https://www.miningrigrentals.com/api/v2/info/algos"
	if (!$AlgosRequest -or !$AlgosRequest.success) {
		return $PoolInfo
	}

	$AlgosRequest.data | ForEach-Object {
		$Algo = $_
		$Pool_Algorithm = Get-MRRAlgo $Algo.name $false
		if ($Pool_Algorithm) {
			[decimal] $Price = 0
			$Algo.stats.prices.last_10.amount = [decimal]$Algo.stats.prices.last_10.amount
			if ($Algo.stats.prices.last_10.amount -gt 0) {
				$Price = $Algo.stats.prices.last_10.amount / [MultipleUnit]::ToValueInvariant("1", $Algo.stats.prices.last_10.unit.ToLower().TrimEnd("h*day"))
			}
			else {
				$Price = [decimal]$Algo.suggested_price.amount / [MultipleUnit]::ToValueInvariant("1", $Algo.suggested_price.unit.ToLower().TrimEnd("h*day"))
			}

			[decimal] $percent = 0;
			$Algo.stats.rented.rigs = [int]$Algo.stats.rented.rigs
			$Algo.stats.available.rigs = [int]$Algo.stats.available.rigs
			if (($Algo.stats.rented.rigs + $Algo.stats.available.rigs) -gt 0) {
				$percent = $Algo.stats.rented.rigs / ($Algo.stats.rented.rigs + $Algo.stats.available.rigs) * 100
			}

			[decimal] $rented = 0
			[decimal] $avail = 0
			if (![string]::IsNullOrEmpty($Algo.stats.rented.hash.hash)) {
				$rented = [MultipleUnit]::ToValueInvariant($Algo.stats.rented.hash.hash, $Algo.stats.rented.hash.unit -replace "h")
			}
			if (![string]::IsNullOrEmpty($Algo.stats.available.hash.hash)) {
				$avail = [MultipleUnit]::ToValueInvariant($Algo.stats.available.hash.hash, $Algo.stats.available.hash.unit -replace "h")
			}
			if (($rented + $avail) -gt 0) {
				$percent = [Math]::Max($percent, $rented / ($rented + $avail) * 100)
			}

			$info = Get-Join "/" @($(if ($Algo.stats.rented.rigs -eq 0) { "0" } else { "$($Algo.stats.rented.rigs)($($Algo.stats.rented.hash.nice))" }),
				$(if ($Algo.stats.available.rigs -eq 0) { "0" } else { "$($Algo.stats.available.rigs)($($Algo.stats.available.hash.nice))" }))
			$algs[$Pool_Algorithm] = [PoolAlgorithmInfo] @{
				Name = $PoolInfo.Name
				Algorithm = $Pool_Algorithm
				Profit = 0 # $Profit
				Info = $info
				Protocol = "stratum+tcp"
				Hosts = @($server.name)
				Port = $server.port
				PortUnsecure = $server.port
				User = $Algo.name
				Password = "x"
				Priority = [Priority]::None
				Extra = @{ price = $Price; totalhash = $rented + $avail; rentpercent = $percent }
			}
		}
	}
}

# filter algo by disabled
$Algos = [Collections.Generic.Dictionary[string, PoolAlgorithmInfo]]::new()
$algs.Keys | ForEach-Object {
	$alg = Get-Algo $_
	if ($alg -and $Cfg.DisabledAlgorithms -notcontains $_) {
		$Algos[$_] = [PoolAlgorithmInfo]$algs[$_];
	}
}

# check rented
try {
	$mrr = [MRR]::new($Cfg.Key, $Cfg.Secret);
	# $mrr.Debug = $true;
	$whoami = $mrr.Get("/whoami")
	if (!$whoami.authed) {
		$whoami = $mrr.Get("/whoami")
		if (!$whoami.authed) {
			Write-Host "MRR: Not authorized! Check Key and Secret." -ForegroundColor Yellow
			return $PoolInfo;
		}
	}
	if ($whoami.permissions.rigs -ne "yes") {
		Write-Host "MRR: Need grant 'Manage Rigs' as 'Yes'." -ForegroundColor Yellow
		return $PoolInfo;
	}

	# check variables
	if (!$Cfg.Target -or $Cfg.Target -lt 5) {
		$Cfg.Target = 50
	}
	if ($Cfg.Target -gt 899) {
		$Cfg.Target = 899
	}
	if ($Cfg.TargetByAlgorithm) {
		$Cfg.TargetByAlgorithm | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
			$var = $Cfg.TargetByAlgorithm."$_"
			if ($var -lt 5) {
				$Cfg.TargetByAlgorithm."$_" = 50
			}
			elseif ($var -gt 899) {
				$Cfg.TargetByAlgorithm."$_" = 899
			}
		}
	}
	if (!$Cfg.Increase -or $Cfg.Increase -lt 0) {
		$Cfg.Increase = 5
	}
	if ($Cfg.Increase -gt 25) {
		$Cfg.Increase = 25
	}
	if (!$Cfg.Decrease -or $Cfg.Decrease -lt 0) {
		$Cfg.Decrease = 1
	}
	if ($Cfg.Decrease -gt 25) {
		$Cfg.Decrease = 25
	}
	if (!$Cfg.MinHours -or $Cfg.MinHours -lt 3) {
		$Cfg.MinHours = 4
	}
	if ($Cfg.MinHours -gt 120) {
		$Cfg.MinHours = 120
	}
	if (!$Cfg.MaxHours) {
		$Cfg.MaxHours = 12
	}
	if ($Cfg.MaxHours -gt 120) {
		$Cfg.MaxHours = 120
	}
	if ($Cfg.MaxHours -lt $Cfg.MinHours) {
		$Cfg.MaxHours = $Cfg.MinHours
	}

	# balance (no balance on slave)
	if (![Config]::UseApiProxy -and $Config.ShowBalance) {
		if ($whoami.permissions.withdraw -eq "no") {
			Write-Host "MRR: Need grant 'Balance/Withdraw' as 'Read-Only'." -ForegroundColor Yellow
		}
		else {
			$balance = $mrr.Get("/account/balance")
			$balance | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
				$confirmed = [decimal]$balance.$_.confirmed
				$unconfirmed = [decimal]$balance.$_.unconfirmed
				if ($confirmed -gt 0 -or $unconfirmed -gt 0) {
					$PoolInfo.Balance.Add($_, [BalanceInfo]::new($confirmed, $unconfirmed))
				}
			}
		}
	}

	# use later in update prices
	$PrevRentedTypes = $global:MRRRentedTypes
	$mine = $null

	if ([Config]::UseApiProxy -and $global:MRRPoolData) {
		$mine = [array]$global:MRRPoolData.Mine
		Write-Host "MRR: Rented rig are received from Master."
	}
	else {
		$mine = $mrr.Get("/rig/mine")
		if ($global:API.Running) {
			$global:API.MRRPool = @{ Server = $server; FailoverServer = $failoverserver; Algos = $algs; Mine = [array]$mine } | ConvertTo-Json -Depth 10
		}
	}
	Remove-Variable algs

	# check rigs
	$result = $mine | Where-Object { $_.name -match $Config.WorkerName }
	if ($result) {
		# $rented_ids = @()
		$rented_types = @()
		$disable_ids = @()
		$enabled_ids = @()
		# smaller max
		if ([Config]::Max -eq 100) { [Config]::Max = 50; [Config]::FTimeout = 260 }
		# reset rented
		$result | ForEach-Object {
			$_.status.rented = $_.status.rented -and [decimal]$_.status.hours -gt 0
			$_.name = ($_.name -replace ([Config]::MRRRigName) -replace "  ", " ").Trim()
		}
		# rented first
		$result | Sort-Object { [bool]$_.status.rented } -Descending | ForEach-Object {
			$Pool_Algorithm = Get-MRRAlgo $_.type
			# $_ | Add-Member Algorithm $Pool_Algorithm
			if ($Pool_Algorithm -and [Config]::ActiveTypes.Length -gt 0 -and $Cfg.DisabledAlgorithms -notcontains $Pool_Algorithm) {
				$KnownTypes = $KnownAlgos.Keys | ForEach-Object { if ($KnownAlgos[$_].ContainsKey($Pool_Algorithm)) { "$_" } }
				# (($KnownAlgos.Values | Where-Object { $_.ContainsKey($Pool_Algorithm) } | Select-Object -First 1) | Select-Object -First 1) -ne $null
				# Write-Host "$Pool_Algorithm known types $($KnownTypes) $($KnownTypes.Count) $rented_types"
				if ($KnownTypes.Length -gt 0 -and
					(([Config]::SoloParty | Where-Object { $KnownTypes -contains $_ }) | Select-Object -first 1) -eq $null -and
					(($rented_types | Where-Object { $KnownTypes -contains $_ }) | Select-Object -first 1) -eq $null -and
					($_.status.rented -or (!$_.status.rented -and (($PrevRentedTypes | Where-Object { $KnownTypes -contains $_ }) | Select-Object -first 1) -eq $null)) -and
					!$Summary.ServiceRunnig()) {
					$enabled_ids += $_.id
				}
				else {
					$disable_ids += $_.id
				}
				$Price = [Math]::Max([decimal]$_.price.BTC.price, 0.00000001) / [MultipleUnit]::ToValueInvariant("1", $_.price.type.ToLower().TrimEnd("h")) * 0.97
				$Hours = [timespan]::FromHours($_.status.hours)
				$user = "$($whoami.username).$($_.id)"
				$Pool_Protocol = "stratum+tcp"
				if ($Config.SSL -eq $true) { $Pool_Protocol = "stratum+ssl" }
				# check over hashrated
				$skip = $false
				$skipPartial = $false
				$rental = $null
				if ($_.status.rented -and $Cfg.DisabledRenters -notcontains $_.renter_id) {
					# every hour check by real miner
					if ($_.poolstatus -eq "offline" -and !$global:MRRHour) {
						Write-Host "MRR: The Renter pool is offline. Skipping of $Pool_Algorithm rental. (The next line with Ping Error is normal due the renter pool is offline)" -ForegroundColor Yellow
						$skip = $skipPartial = $true
					}
					else {
						$rental = $mrr.Get("/rental/$($_.rental_id)")
						# $rental | ConvertTo-Json -Depth 10 | Out-File "1.txt" -Force
						# $_ | ConvertTo-Json -Depth 10 | Out-File "1.txt" -Append
						if ($global:MRRHour) {
							$rentalgraph = $mrr.Get("/rental/$($_.rental_id)/graph")
							# $rentalgraph | ConvertTo-Json -Depth 10 | Out-File "1.txt" -Append
							$offlinedata = $rentalgraph.chartdata.pooloffline
							if (![string]::IsNullOrWhiteSpace($offlinedata) -and $offlinedata -ne "none") {
								$offline = 0
								$offlinedata.Split(",", [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
									$tmp = $_.Split(":", [StringSplitOptions]::RemoveEmptyEntries)
									if ($tmp.Length -eq 2) {
										$offline += ([Convert]::ToDecimal($tmp[1]) - [Convert]::ToDecimal($tmp[0]))
									}
								}
								$global:MRROffline."$($_.rental_id)" = [timespan]::FromMilliseconds($offline).TotalHours
							}
							Remove-Variable offlinedata, rentalgraph
						}
						if ($rental) {
							$hsh = [decimal]$rental.hashrate.average.hash / [decimal]$rental.hashrate.advertised.hash
							$time = ([decimal]$rental.extended + [decimal]$rental.length + $global:MRROffline."$($_.rental_id)" - $Hours.TotalHours) / [decimal]$rental.length
							if ($time -gt 1) { $time = 1 }
							$hsh = $hsh * $time * 100 - 100
							# Write-Host "HASHTOTAL: $hsh"
							if ($hsh -gt -1) {
								$extra = 0
								if ($_.available_status -notmatch "available") { $extra = -1 }
								# Write-Host "Percent: $($hsh - $extra)   status: $($Hours.TotalHours)   $($rental.length)"
								if (($hsh - $extra) -ge 0) {
									$skip = $true
									Write-Host "MRR: Skipping $([SummaryInfo]::Elapsed($Hours)) of $Pool_Algorithm rental by $($rental.renter) ($($_.renter_id)) due to exceeding the hashrate by $([decimal]::Round($hsh, 2))%." -ForegroundColor Yellow
								}
							}
							Remove-Variable time, hsh
						}
					}
					if ($skip) {
						$redir =  $mrr.Get("/rig/$($_.id)/port")
						try { $redir.port = [int]$redir.port } catch { }
						$png = $false
						if ($redir.port -is [int]) {
							$png = Ping-MRR $redir.server $redir.port "$($whoami.username).$($_.id)" $_.id ($Config.SSL -match "only") (($Summary.LoopCount % 2) -eq 1)
						}
						if (!$png) {
							$png = Ping-MRR $server.name $server.port "$($whoami.username).$($_.id)" $_.id ($Config.SSL -match "only") (($Summary.LoopCount % 2) -eq 1)
						}
						Remove-Variable png, redir
					}
					# end rent if left 30 seconds of rent
					if (!$skip -and $Hours.TotalSeconds -le ($Config.LoopTimeout / 2)) {
						$skip = $true
					}
					if ($skip) {
						$disable_ids += $_.id
					}
				}
				# possible bug - algo unknown, but rented
				if ($_.status.rented -and (!$skip -or $skipPartial) -and $Cfg.DisabledRenters -notcontains $_.renter_id) {
					# $rented_ids += $_.id
					$KnownTypes | ForEach-Object {
						$tp = $_
						$rented_types += $tp
						$PrevRentedTypes = $PrevRentedTypes | Where-Object { $_ -ne $tp }
						Remove-Variable tp
					}
				}
				Remove-Variable skipPartial
				if ($_.status.rented -and !$skip -and $Cfg.DisabledRenters -notcontains $_.renter_id) {
					# calc current rig profit
					$infoExtra = [string]::Empty
					if ($KnownTypes.Length -gt 0) {
						$rigproft = ((($KnownAlgos.Keys | Where-Object { $KnownTypes -contains $_ } | ForEach-Object { $KnownAlgos[$_] }) |
							ForEach-Object { ($_.Values | Where-Object { $_ -and $_.BestProfit -gt 0 } | Measure-Object BestProfit -Maximum) }) | Measure-Object -Property Maximum -Sum).Sum
						if ($rigproft -gt 0) {
							if ($rental) {
								$SpeedAdv = [decimal]$rental.hashrate.advertised.hash * [MultipleUnit]::ToValueInvariant("1", $rental.hashrate.advertised.type.ToLower().TrimEnd("h"))
							}
							else {
								$SpeedAdv = [decimal]$_.hashrate.advertised.hash * [MultipleUnit]::ToValueInvariant("1", $_.hashrate.advertised.type.ToLower().TrimEnd("h"))
							}
							$val = ($Price * $SpeedAdv / $rigproft  - 1) * 100;
							$infoExtra = "$([decimal]::Round($val))"
							if ($infoExtra -notcontains "-") { $infoExtra = "+" + $infoExtra }
							Remove-Variable val, SpeedAdv
						}
						Remove-Variable rigproft
					}
					$hashmatch = [string]::Empty
					$renterName = $_.renter_id
					$hashnice = $_.hashrate.advertised.nice
					$of = [string]::Empty
					if ($rental) {
						$renterName = $rental.renter + "(" + $renterName +")"
						$hashnice = $rental.hashrate.advertised.nice
						$hashmatch = "/$([decimal]::Round([decimal]$rental.hashrate.average.hash / [decimal]$rental.hashrate.advertised.hash * 100))"
						$of = " of $([SummaryInfo]::Elapsed([timespan]::FromHours($rental.length)))";
					}
					if (![string]::IsNullOrWhiteSpace("$infoExtra$hashmatch")) { $hashmatch += "%" }
					$info = "$([SummaryInfo]::Elapsed($Hours))$infoExtra$hashmatch"
					Remove-Variable infoExtra
					$redir =  $mrr.Get("/rig/$($_.id)/port")
					try { $redir.port = [int]$redir.port } catch { }
					$ping = $true
					if ($redir.port -is [int]) {
						$ping = Ping-MRR $redir.server $redir.port "$($whoami.username).$($_.id)" $_.id ($Config.SSL -match "only")
					}
					if ($redir.port -isnot [int] -or !$ping) {
						Write-Host "MRR: Switch server." -ForegroundColor Yellow
						$mrr.Put("/rig/$($_.id)", @{ "server" = $(if ($redir.server -eq $server.name) { $failoverserver.name } else { $server.name }) })
						$redir = $mrr.Get("/rig/$($_.id)/port")
						try { $redir.port = [int]$redir.port } catch {
							Write-Host "Unknown port value in `"/rig/port`" answer: $($redir | ConvertTo-Json)" -ForegroundColor Red
							$redir.port = $server.port
						}
					}
					$Algos[$Pool_Algorithm] = [PoolAlgorithmInfo]@{
						Name = $PoolInfo.Name
						Algorithm = $Pool_Algorithm
						Profit = $Price
						Info = $info
						Protocol = $Pool_Protocol
						Hosts = @($redir.server)
						Port = $redir.port
						PortUnsecure = $redir.port
						User = $user
						Password = "x"
						Priority = [Priority]::Unique
					}
					Write-Host "MRR: $renterName rented $Pool_Algorithm at $hashnice`H/s and $([SummaryInfo]::Elapsed($Hours))$of left: $($_.name)" -ForegroundColor Yellow
					Remove-Variable renterName, hashnice
					# disable before rent end
					if ($Hours.TotalSeconds -le ($Config.LoopTimeout * $Config.MaximumAllowedGrowth) ) {
						$disable_ids += $_.id
					}
				}
				else {
					$info = [string]::Empty
					$extra = [hashtable]::new()
					if ($Algos.ContainsKey($Pool_Algorithm)) {
						$info = $Algos[$Pool_Algorithm].Info
						$extra = $Algos[$Pool_Algorithm].Extra
					}
					$Algos[$Pool_Algorithm] = [PoolAlgorithmInfo]@{
						Name = $PoolInfo.Name
						Algorithm = $Pool_Algorithm
						Profit = $Price
						Info = $info
						Protocol = $Pool_Protocol
						Hosts = @($server.name)
						Port = $server.port
						PortUnsecure = $server.port
						User = $user
						Password = "x"
						Priority = [Priority]::None
						Extra = $extra
					}
				}
				Remove-Variable rental, skip, Hours, user, Price, Pool_Protocol
			}
			else {
				$disable_ids += $_.id
			}
		}

		$Algos.Values | ForEach-Object { $PoolInfo.Algorithms.Add($_) }
		$global:MRRRentedTypes = $rented_types

		# on first run skip enable/disable
		if (($KnownAlgos.Values | Measure-Object -Property Count -Sum).Sum -gt 0) {
			# disable
			$ids = @()
			$algs = @()
			[string] $alg
			$result | Where-Object { $_.available_status -match "available" -and $disable_ids -contains $_.id } | ForEach-Object {
				$alg = Get-MRRAlgo $_.type $false
				$_.available_status = "disabled"
				$ids += $_.id
				$algs += $alg
			}
			if ($ids.Length -gt 0) {
				Write-Host "MRR: Disable $($algs -join ", ")" -ForegroundColor Yellow
				$mrr.Put("/rig/$($ids -join ";")", @{ "status" = "disabled"; "server" = $server.name; "minhours" = $Cfg.MinHours; "maxhours" = $Cfg.MaxHours })
			}
			# enable
			$ids = @()
			$algs = @()
			$result | Where-Object { $_.available_status -notmatch "available" -and $enabled_ids -contains $_.id -and $disable_ids -notcontains $_.id } | ForEach-Object {
				$alg = Get-MRRAlgo $_.type
				$_.available_status = "available"
				$ids += $_.id
				$algs += $alg
			}
			if ($ids.Length -gt 0) {
				Write-Host "MRR: Available $($algs -join ", ")" -ForegroundColor Yellow
				$mrr.Put("/rig/$($ids -join ";")", @{ "status" = "enabled"; "server" = $server.name; "minhours" = $Cfg.MinHours; "maxhours" = $Cfg.MaxHours })
			}
			Remove-Variable ids, algs, alg
			# ping
			$result | Where-Object { !$_.status.rented -and $enabled_ids -contains $_.id -and $disable_ids -notcontains $_.id } | ForEach-Object {
				$alg = Get-MRRAlgo $_.type
				# Write-Host "$alg`: $($_ | ConvertTo-Json -Depth 10 -Compress)"
				$KnownTypes = $KnownAlgos.Keys | ForEach-Object { if ($KnownAlgos[$_].ContainsKey($alg)) { $_ } }
				$SpeedAdv = [decimal]$_.hashrate.advertised.hash * [MultipleUnit]::ToValueInvariant("1", $_.hashrate.advertised.type.ToLower().TrimEnd("h"))
				$Price = [decimal]$_.price.BTC.price / [MultipleUnit]::ToValueInvariant("1", $_.price.type.ToLower().TrimEnd("h"))
				$SpeedCalc = (($KnownAlgos.Values | Foreach-Object { $t = $_[$alg]; if ($t) { $t } }) | Measure-Object Speed -Sum).Sum
				$warn = if ($SpeedCalc * 0.95 -gt $SpeedAdv -or $SpeedCalc * 1.05 -lt $SpeedAdv) { " != $([MultipleUnit]::ToString($SpeedCalc) -replace `" `")" } else { [string]::Empty }
				$color = if ($SpeedCalc * 1.05 -lt $SpeedAdv) { "Red" } else { "Yellow" }
				$thash = $Algos[$alg].Extra["totalhash"]
				$hashpercent = if ($thash -gt 0 -and ($thash - $SpeedAdv) -gt 0) { "($([decimal]::Round($SpeedAdv * 100 / ($thash - $SpeedAdv), 2))%) " } else { [string]::Empty }
				Write-Host "MRR: Online $alg ($(Get-Join ", " $KnownTypes)), $([decimal]::Round($SpeedAdv * $Price, 8)), $hashpercent" -NoNewline
				if (![string]::IsNullOrWhiteSpace($warn)) {
					Write-Host "$($_.hashrate.advertised.nice)$warn`H/s" -NoNewline -ForegroundColor $color
				} else {
					Write-Host "$($_.hashrate.advertised.nice)$warn`H/s" -NoNewline
				}
				Write-Host ", $($_.minhours)-$($_.maxhours)h, $($_.region), $($_.rpi): $($_.name) - $($Algos[$alg].Info)"
				$ping = Ping-MRR $server.name $server.port "$($whoami.username).$($_.id)" $_.id ($Config.SSL -match "only")
			}
			# show top 3
			# $Algos.Values | Where-Object { $_.Profit -eq 0 -and [decimal]$_.Password -gt 20 } | Sort-Object { [decimal]$_.Password } -Descending | Select-Object -First 10 | ForEach-Object {
			# 	Write-Host "Check algo $($_.Algorithm) rented: $("{0:N1}" -f [decimal]$_.Password)% $($_.Info)"
			# }
		}
	}
	else {
		if ([Config]::ActiveTypes.Length -gt 0) {
			Write-Host "MRR: No compatible rigs found! Write `"$($Config.WorkerName)`" key string to MRR rig name." -ForegroundColor Yellow
		}
	}

	if (!$global:FChange -and [Config]::ActiveTypes.Length -gt 0 -and ($KnownAlgos.Values | Measure-Object -Property Count -Sum).Sum -gt 0) {
		$sumprofit = (($KnownAlgos.Values | ForEach-Object { ($_.Values | Where-Object { $_ -and $_.BestProfit -gt 0 } | Measure-Object BestProfit -Maximum) }) |
			Measure-Object -Property Maximum -Sum).Sum
		Write-Host "MRR: Rig target profit: $([decimal]::Round($sumprofit, 8)) + $($Cfg.Target)% = $([decimal]::Round($sumprofit * (100 + $Cfg.Target) / 100, 8))"
		if ($Cfg.TargetByAlgorithm) {
			Write-Host "MRR: Other target profit: $(($Cfg.TargetByAlgorithm | ConvertTo-Json -Compress) -replace "{" -replace "}", "%" -replace ",", "%, " -replace '"' -replace ":", ": ")"
		}
		[bool] $save = $false
		[array] $rigBatch = @()
		$Algos.Values | Where-Object { $Cfg.DisabledAlgorithms -notcontains $_.Algorithm } | ForEach-Object {
			$Algo = $_
			$KnownTypes = $KnownAlgos.Keys | ForEach-Object { if ($KnownAlgos[$_].ContainsKey($Algo.Algorithm)) { $_ } }
			if ($KnownTypes.Length -gt 0) {
				$rigproft = ((($KnownAlgos.Keys | Where-Object { $KnownTypes -contains $_ } | ForEach-Object { $KnownAlgos[$_] }) |
					ForEach-Object { ($_.Values | Where-Object { $_ -and $_.Profit -gt 0 } | Measure-Object Profit -Maximum) }) | Measure-Object -Property Maximum -Sum).Sum
				$trgt = $Cfg.Target;
				if ($Cfg.TargetByAlgorithm."$($Algo.Algorithm)" -gt 0) {
					$trgt = $Cfg.TargetByAlgorithm."$($Algo.Algorithm)"
				}
				$persprofit = $rigproft * (100 + $trgt) / 100
				# check lower floor
				$lf = ($KnownAlgos.Keys | ForEach-Object { Get-ProfitLowerFloor $_ } | Measure-Object -Sum).Sum
				$persprofit = [math]::Max($persprofit, $lf)
				# Write-Host "$($Algo.Algorithm) Profit rig $([decimal]::Round($sumprofit, 8)), alg $([decimal]::Round($persprofit, 8))"
				$Speed = (($KnownAlgos.Values | ForEach-Object { $t = $_[$Algo.Algorithm]; if ($t) { $t } }) | Measure-Object Speed -Sum).Sum
				$Profit = $Speed * $Algo.Extra["price"]
				$hashpercent = if ($Algo.Extra["totalhash"] -gt 0) { "($([decimal]::Round($Speed * 100 / ($Algo.Extra["totalhash"]), 2))%) " } else { [string]::Empty }
				if ($Algo.Profit -eq 0 -and $Profit -gt 0) {
					Write-Host "MRR: $($Algo.Algorithm) ($(Get-Join ", " $KnownTypes)), speed: $hashpercent$([MultipleUnit]::ToString($Speed) -replace `" `")H/s, profit: $([decimal]::Round($Profit, 8)), rented: $("{0:N1}" -f $Algo.Extra["rentpercent"])% - $($Algo.Info)"
					if ($global:HasConfirm -and !$global:HasBenchmark) {
						if (Get-Question "Add rig to MRR for algorithm '$($Algo.Algorithm)'") {
							$prms = @{
								"name" = "$($whoami.username) $($Config.WorkerName) $([Config]::MRRRigName)"
								"hash" = @{ "hash" = $Speed; "type" = "hash" }
								"type" = $Algo.User
								"server" = $server.name
								"minhours" = $Cfg.MinHours
								"maxhours" = $Cfg.MaxHours
								"status" = $(if ($global:MRRRentedTypes) { "disabled" } else { "enabled" })
								"price" = @{ "type" = "hash"; "btc" = @{ "price" = $Algo.Extra["price"] } }
							}
							if ($Cfg.Wallets) {
								$Cfg.Wallets | Where-Object { [Config]::MRRWallets -contains $_ } | ForEach-Object {
									$prms.price."$_" = @{ "enabled" = $true; "autoprice" = $true }
								}
							}
							$mrr.Put("/rig", $prms)
						}
						else {
							$Cfg.DisabledAlgorithms += $Algo.Algorithm
							$save = $true
						}
					}
					else {
						$global:NeedConfirm = $true
					}
				}
				else {
					# find rig
					$rig = ($result | Where-Object { (Get-MRRAlgo $_.type) -eq $Algo.Algorithm }) | Select-Object -First 1
					if ($rig -and ((!$rig.status.rented -and $rig.available_status -match "available") -or $PrevRentedTypes)) {
						$SpeedAdv = [decimal]$rig.hashrate.advertised.hash * [MultipleUnit]::ToValueInvariant("1", $rig.hashrate.advertised.type.ToLower().TrimEnd("h"))
						$prft = $SpeedAdv * [decimal]$rig.price.BTC.price / [MultipleUnit]::ToValueInvariant("1", $rig.price.type.ToLower().TrimEnd("h"))
						$riggrowproft = $persprofit * $Config.MaximumAllowedGrowth
						# Write-Host "MRR: Check profit $($Algo.Algorithm) ($(Get-Join ", " $KnownTypes)) $([decimal]::Round($prft, 8)) grater $([decimal]::Round($persprofit, 8)) max $([decimal]::Round($riggrowproft, 8))"
						if ((($PrevRentedTypes | Where-Object { $KnownTypes -contains $_ }) | Select-Object -first 1) -ne $null) {
							if ($prft -lt $persprofit) { $prft = $persprofit }
							$persprofit = $prft * (100 + $Cfg.Increase) / 100
						}
						elseif ($global:MRRHour -and ($prft * (100 - $Cfg.Decrease) / 100) -gt $persprofit) {
							$persprofit = $prft * (100 - $Cfg.Decrease) / 100
						}
						elseif ($prft -lt $persprofit) {
							$persprofit *= 1.01
						}
						elseif ($prft -gt $riggrowproft) {
							$persprofit = $riggrowproft
						}
						else {
							$persprofit = 0
						}
						[decimal] $prc = $persprofit / $SpeedAdv * [MultipleUnit]::ToValueInvariant("1", $rig.price.type.ToLower().TrimEnd("h"))
						if ($prc -gt 0) {
							Write-Host "MRR: Update $($Algo.Algorithm) ($(Get-Join ", " $KnownTypes)), price $($rig.price.BTC.price)->$([decimal]::Round($prc, 8)), profit $([decimal]::Round($prft, 8))->$([decimal]::Round($persprofit, 8))" -ForegroundColor Yellow
							$prms = @{
								"id" = $rig.id
								"price" = @{ "type" = $rig.price.type; "btc" = @{ "price" = $prc; } }
								"server" = $server.name
								"minhours" = $Cfg.MinHours
								"maxhours" = $Cfg.MaxHours
							}
							[Config]::MRRWallets | ForEach-Object {
								$wal = $_
								$prms.price."$wal" = @{ "enabled" = $false; "autoprice" = $true }
								if ($Cfg.Wallets) {
									$Cfg.Wallets | ForEach-Object {
										if ([string]::Equals($wal, $_, [StringComparison]::InvariantCultureIgnoreCase)) {
											$prms.price."$wal" = @{ "enabled" = $true; "autoprice" = $true }
										}
									}
								}
							}
							$rigBatch += $prms
						}
					}
				}
			}
		}
		if ($rigBatch.Count -eq 1) {
			$mrr.Put("/rig/$($rigBatch[0].id)", $rigBatch[0])
		}
		elseif ($rigBatch.Count -gt 1) {
			Write-Host "MRR: Post rig batch update ..." -ForegroundColor Green
			$mrr.Post("/rig/batch", @{ rigs = $rigBatch })
		}
		Remove-Variable rigBatch
		if ($save) {
			[BaseConfig]::Save($configpath, $Cfg)
		}
		$global:MRRHour = $false
	}

	# info as standart pool
	$PoolInfo.HasAnswer = $true
	$PoolInfo.AnswerTime = [DateTime]::Now
}
catch {
	Write-Host $_
}
finally {
	if ($mrr) {	$mrr.Dispose() }
}

return $PoolInfo