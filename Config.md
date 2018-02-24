# Сonfiguration manual of MindMiner
Any configuration stored in json format.

## Pools
Pools configuration placed in Pools folder and named as pool name and config extension.
Look like this "PoolName.config.txt".

Any pool has this config:
```json
{
    "AverageProfit":  "1 hour 30 min",
    "Enabled":  false
}
```

* **Enabled** [bool] (true|false) - enable or disable pool for mine.
* **AverageProfit** [string] - averages a profit on the coins at the specified [time interval](https://github.com/Quake4/HumanInterval/blob/master/README.md).
* ***APiKey*** [string] - api key for get balance on MiningPoolHub. See "Edit Account" section and "API KEY" value in MPH account.

Pools config read on each loop. You may change configuration at any time and it will be applied on the next loop. If you delete pool config it will be created on the next loop after your confirm and answer at console window.

## Miners
Miners configuration placed in Miners folder and named as miner name and config extension.
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

Miners config read on each loop. You may change configuration at any time and it will be applied on the next loop. If you delete miner config it will be created default on the next loop.

