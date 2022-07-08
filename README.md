# HDD Survival analysis, based on data from BackBlaze 2013-2022

## Data download and preprocess

* `raw/download.jl` - download script
* `raw/import_simple.jl` - import data from .csv files into SQLite DB
* `raw/analysis.sql` - aggregate data 

## Data Structure (aggregated):

* `serial_number`
  
  * `id` - HDD id (integer)
  * `val` - HDD serial number (string)

* `model`
  
  * `id` - HDD model id (integer)
  * `val` - HDD model name (string)

* `model_serial` 

  * `model_id` - HDD model id (integer)
  * `serial_number_id` - HDD id (integer)

* `model_capacity`

  * `model_id` - HDD model id (integer)
  * `capacity_bytes` - HDD capacity in bytes (integer)

* `drive_surv`

  * `model_id` - HDD model id (integer)
  * `serial_number_id` - HDD serial id (integer)
  * `failure` - `1`: hard drive failed , `0`: hard drive survived past observation window (i.e it was *censored*)
  * `start` - first day HDD was available (days since 2010-01-01 ) (integer)
  * `stop` - last day HDD was available (days since 2010-01-01 ) (integer)
  * `age` - number of days before failure or censoring (integer)
  