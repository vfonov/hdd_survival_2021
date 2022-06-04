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
    model_id  = (DBInterface.execute(conn,"select id from model where val=?",[model]) |> DataFrame ).id[1]
    drive_surv = DBInterface.execute(conn,"select age,failure from drive_surv where model_id=? and age>0",[model_id]) |> DataFrame

    #transform(drive_surv,:failure => ByRow(x->x>0) => :failure)
    drive_surv[!,:failure] = drive_surv[!,:failure].>0

    return drive_surv
end


end
