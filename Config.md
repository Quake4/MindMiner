# Сonfiguration manual of MindMiner
Any configuration stored in json format.

## MindMiner config
MindMiner config placed in config.txt file into root application folder.

Main config is read only at the start of the MindMiner.

```json
{
    "Region": "Europe",
    "SSL": true,
    "Wallet": { "BTC":  "BTC Wallet" },
    "WorkerName": "Worker name",
    "Login": "Login",
    "Password": "x",
    "CheckTimeout": 5,
    "LoopTimeout": 60,
    "NoHashTimeout": 10,
    "AverageCurrentHashSpeed": 180,
    "AverageHashSpeed": "1 day",
    "Verbose": "Normal",
    "ShowBalance": true,
    "AllowedTypes": [ "CPU", "nVidia", "AMD", "Intel" ],
    "Currencies": { "BTC": 8, "USD": 2, "EUR": 2 }
}
```

* ***Region*** [enum] (**Europe**|Usa|China|Japan|Other) - pool region.
* ***SSL*** [bool] (**true**|false) - use secure protocol if possible.
* **Wallet** [key value collection] - coin wallet addresses (now support one or two wallets: `BTC` and/or `LTC`):
    * **Key** [string] - coin short name (if specified `"LTC"` wallet its use at Zergpool).
    * **Value** [string] - coin wallet address.
* ***WorkerName*** [string] - worker name. If empty use machine name.
* **Login** [string] - login for pool with registration (MiningPoolHub).
* ***Password*** [string] - password. If empty default value `"x"`.
* ***CheckTimeout*** [int] - check timeout in seconds for read miner speed. Recomended value from 3 seconds to 15 secounds.
* ***LoopTimeout*** [int] - loop timeout in second. Recomended value from 30 seconds to five minute.
* ***NoHashTimeout*** [int] - timeout in minutes to disable miner after determining zero hash.
* ***ShowBalance*** [bool] - show balance if value equal true, else dont show.
* ***AverageCurrentHashSpeed*** [int] - miner average current hash speed in seconds. Recomended value from 120 second to five minute.
* ***AverageHashSpeed*** [string] - miner average hash speed in  [time interval](https://github.com/Quake4/HumanInterval/blob/master/README.md). Recomeded value from few hours to one day.
* ***Verbose*** [enum] (Full|**Normal**|Minimal) - verbose level.
* ***AllowedTypes*** [enum array] (CPU|nVidia|AMD|Intel) - allowed devices to mine.
* ***Currencies*** [key value collection] - currencies for output (maximum supported 3). If empty use by default `{ "BTC": 8, "USD": 2}`:
    * **Key** [string] - currency name from [supported list](https://api.coinbase.com/v2/exchange-rates?currency=BTC) + `mBTC`.
    * **Value** [int] - the number of digits after the decimal point.

## Pools
Pools configuration placed in Pools folder and named as pool name and config extension.

Pools config read on each loop. You may change configuration at any time and it will be applied on the next loop. If you delete pool config it will be created default on the next loop after your confirm and answer at console window.

Look like this "PoolName.config.txt".

Any pool has this config:
```json
{
    "AverageProfit": "1 hour 30 min",
    "Enabled": false,
    "EnabledAlgorithms": [ "Bitcore", "X17", "X16r" ],
    "DisabledAlgorithms": null
}
```

* **Enabled** [bool] (true|false) - enable or disable pool for mine.
* **AverageProfit** [string] - averages a profit on the coins at the specified [time interval](https://github.com/Quake4/HumanInterval/blob/master/README.md).
* ***EnabledAlgorithms*** [string array] - set of enabled algorithms. If the value is null or empty, this means that all algorithms are enabled from the pool otherwise only the specified algorithms are enabled.
* ***DisabledAlgorithms*** [string array] - set of disabled algorithms. Always disables the specified algorithms.

### Specific for MiningPoolHub
* ***APiKey*** [string] - api key for get balance on MiningPoolHub. See "Edit Account" section and "API KEY" value in MPH account.

### Specific for NiceHash
* ***Wallet*** [string] - internal NiceHash wallet.

### Specific for ZergPool
* ***SpecifiedCoins*** [array] - specifing preferred coin for algo. (Algo as key and sign of coin as value or array of value for several sign of coins)

Example:
```json
{
    "AverageProfit":  "1 hour 30 min",
    "Enabled":  true,
    "SpecifiedCoins": { "C11": "SPD", "NeoScrypt": [ "SPK", "GBX"], "Phi": "LUX" }
}
```

If algo has two or three conis you must specify one coin. If it coin down then MindMiner to be mine just algo without specified coin (example Phi algo need specify only LUX, not need specify together FLM).
This feature give you a very great opportunity to increase profit.

## Miners
Miners configuration placed in Miners folder and named as miner name and config extension.

Miners config read on each loop. You may change configuration at any time and it will be applied on the next loop. If you delete miner config it will be created default on the next loop.

Look like this "MinerName.config.txt".

Simple miner config:
```json
{
    "Algorithms":  [
                       {
                           "ExtraArgs":  null,
                           "BenchmarkSeconds":  0,
                           "Enabled":  true,
                           "Algorithm":  "cryptonight"
                       },
                       {
                           "ExtraArgs":  "-lite",
                           "BenchmarkSeconds":  0,
                           "Enabled":  true,
                           "Algorithm":  "cryptolite"
                       }
                   ],
    "BenchmarkSeconds":  60,
    "Enabled":  true
}
```

Xmr-stak-cpu miner config:
```json
{
    "ThreadMask":  null,
    "BenchmarkSeconds":  25,
    "ConfigFile":  null,
    "ThreadCount":  3,
    "Enabled":  true
}
```

* common:
    * **Enabled** [bool] (true|false) - enable or disable miner.
    * **BenchmarkSeconds** [int] - default timeout in seconds for benchmark.
* algorithms miners:
    * **Algorithms** [array] - array of miner algorithms.
        * **Enabled** [bool] (true|false) - enable or disable algorithm.
        * ***BenchmarkSeconds*** [int] - default timeout in seconds for benchmark. If not set or zero use miner BenchmarkSeconds.
        * **Algorithm** [string] - pool algorithm and miner algorithm parameter.
        * **ExtraArgs** [string] - miner extra parameters.
* xmr-stak-cpu miner (must be set value in one parameter or all empty for defaults):
    * **ThreadMask** [string] - array of 0 or 1 of cpu mask to enable or disable thread. Mask "0101" enabled two thread from four.
    * **ConfigFile** [string] - user created filename miner config.
    * **ThreadCount** [int] - thread count.
