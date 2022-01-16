module Backblaze

using SQLite,DataFrames
using Logging
using CategoricalArrays

export backblaze_drive_surv

conn = nothing 

function __init__()
    global conn = SQLite.DB("raw/backblaze.sqlite3")
end

function backblaze_drive_surv(model)
    @info(conn)

    model_id  = (DBInterface.execute(conn,"select id from model where val=?",[model]) |> DataFrame ).id[1]
    drive_surv = DBInterface.execute(conn,"select age,failure from drive_surv where model_id=?",[model_id]) |> DataFrame

    transform!(drive_surv,:failure => ByRow(x-> x==1) => :FAIL)
end


end
