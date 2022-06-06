module Backblaze

using SQLite,DataFrames
using Logging
using CategoricalArrays
export backblaze_drive_surv,model_stats,backblaze_ref_date
using Dates

conn = nothing
backblaze_ref_date=Date("2010-01-01")


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

function model_stats()
    DBInterface.execute(conn,"select m.val as model,count(distinct s.serial_number_id) from model_serial as s left join model as m on s.model_id=m.id group by 1 order by 2 desc") |> DataFrame
end


end
