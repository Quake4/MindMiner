function Get-RateInfo {
	$json = Get-UrlAsJson "https://api.coinbase.com/v2/exchange-rates?currency=BTC"

	$result = [Collections.Generic.List[object]]::new()
	$Config.Currencies | ForEach-Object {
		if ([string]::Equals($_[0], "BTC", [StringComparison]::InvariantCultureIgnoreCase)) {
			$result.Add(@("BTC", [decimal]1))
		}
		elseif ([string]::Equals($_[0], "mBTC", [StringComparison]::InvariantCultureIgnoreCase)) {
			$result.Add(@("mBTC", [decimal]1000))
		}
		elseif ($json.data.rates."$($_[0])") {
			$result.Add(@($_[0], [decimal]$json.data.rates."$($_[0])"))
		}
	}
	,$result
}