using SQLite
using CSV
using DataFrames
using Dates

#
#using Profile
#using StatProfilerHTML
#

# generate SQLite file
conn = SQLite.DB("backblaze.sqlite3")
ref_date=Date("2010-01-01")

SQLite.execute(conn,
"""
create table if not exists serial_number(
    val TEXT NOT NULL,
    id  INTEGER NOT NULL
)
"""
);

SQLite.execute(conn,
"""
create table if not exists model(
    val TEXT NOT NULL,
    id  INTEGER NOT NULL
)
"""
);


SQLite.execute(conn, 
"""
CREATE TABLE if not exists drive_stats(
    day INTEGER NOT NULL,
    serial_number_id INTEGER NOT NULL,
    model_id INTEGER NOT NULL,
    capacity_bytes INTEGER (8) NOT NULL,
    failure INTEGER (1) NOT NULL,
    
    smart_1_normalized INTEGER,
    smart_1_raw INTEGER,
    smart_4_raw INTEGER,
    smart_5_raw INTEGER,
    smart_9_raw INTEGER,
    smart_12_raw INTEGER,
    smart_22_normalized INTEGER,
    smart_170_normalized INTEGER,
    smart_174_raw INTEGER,            

    smart_178_normalized INTEGER,
    smart_178_raw INTEGER,
    smart_187_raw INTEGER,
    smart_188_raw INTEGER,
    smart_192_raw INTEGER,
    smart_193_raw INTEGER,
    smart_194_raw INTEGER,

    smart_196_raw INTEGER,
    smart_197_raw INTEGER,
    smart_198_raw INTEGER,

    smart_231_normalized INTEGER,
    smart_232_normalized INTEGER,

    smart_233_normalized INTEGER,
    smart_241_raw INTEGER,
    smart_242_raw INTEGER
    );
"""
);

fields=["day" ,
    "serial_number_id" ,
    "model_id" ,
    "capacity_bytes",
    "failure" ,

    "smart_1_normalized",
    "smart_1_raw",
    "smart_4_raw",
    "smart_5_raw",
    "smart_9_raw",
    "smart_12_raw",
    "smart_22_normalized",
    "smart_170_normalized",
    "smart_174_raw",            

    "smart_178_normalized",
    "smart_178_raw",
    "smart_187_raw",
    "smart_188_raw",
    "smart_192_raw",
    "smart_193_raw",
    "smart_194_raw",

    "smart_196_raw",
    "smart_197_raw",
    "smart_198_raw",

    "smart_231_normalized",
    "smart_232_normalized",

    "smart_233_normalized",
    "smart_241_raw",
    "smart_242_raw",
]

serial_number=Dict()
model=Dict()
serial_id=0
model_id=0

# load from SQL first

function load_dict(tbl)
    rr=Dict()
    for r in DBInterface.execute(conn,"select val,id from $(tbl)")
        rr[r.val]=r.id
    end
    return rr
end

serial_number=load_dict("serial_number")
serial_id=maximum(values(serial_number))
model=load_dict("model")
model_id=maximum(values(model))


function serial_to_id(x)
    if haskey(serial_number,x)
        return get(serial_number,x,serial_id)
    else
        global serial_id=serial_id+1
        return get!(serial_number,x,serial_id)
    end
end

function model_to_id(x)
    if haskey(model,x)
        return get(model,x,model_id)
    else
        global model_id=model_id+1
        return get!(model,x,model_id)
    end
end

function dict_to_table(d,t)
    SQLite.transaction(conn) do 
        SQLite.execute(conn,"delete from $(t)");
        stmt = SQLite.Stmt(conn,"insert into $(t)(val,id) values (?,?)")

        for r in d
            SQLite.execute(stmt, [r[1], r[2]] )
        end
    end
end

function normalize!(df)
    for f in setdiff(fields,names(df))
        insertcols!(df, f=>nothing)
    end
    # enforce data integrity
    #
    # date TEXT NOT NULL,
    # serial_number TEXT NOT NULL,
    # model TEXT NOT NULL,
    # capacity_bytes INTEGER (8) NOT NULL,
    # failure INTEGER (1) NOT NULL,
    #subset(df,:date=>ByRow())
    dropmissing!(df, [:date,:serial_number,:model,:capacity_bytes,:failure])
    transform!(df,:date=>ByRow(x -> (x-ref_date).value ) => :day )
    transform!(df,:serial_number=>ByRow(serial_to_id) => :serial_number_id )
    transform!(df,:model=>ByRow(model_to_id) => :model_id )

    # select only interesting fields
    return df[!,fields]    
end

function process_table(t)

    df=CSV.read(t, DataFrame;types=Dict(
	    "date"=>Date,"serial_number"=>String,"model"=>String,"capacity_bytes"=>Int64,"failure"=>Int),
        dateformat="yyyy-mm-dd")
    # enforce data integrity
    #
    # date TEXT NOT NULL,
    # serial_number TEXT NOT NULL,
    # model TEXT NOT NULL,
    # capacity_bytes INTEGER (8) NOT NULL,
    # failure INTEGER (1) NOT NULL,
    #subset(df,:date=>ByRow())

    # subset!(df, 
    #    :date => ByRow(!isnothing),
    #    :serial_number => ByRow(!isnothing),
    #    :model => ByRow(!isnothing),
    #    :capacity_bytes => ByRow(!isnothing),
    #    :failure => ByRow(!isnothing),
    #    )

    df = normalize!(df)

    n = join( fields,"," )
    q = join( repeat(["?"], length(fields)), "," )

    SQLite.transaction(conn) do 
        stmt = SQLite.Stmt(conn,"insert into drive_stats($(n)) values ($(q))")

        for r in 1:nrow(df)
            SQLite.execute(stmt, [ df[r,ii] for ii in 1:ncol(df) ] )
        end
    end
    # HACK?
    df = nothing

    dict_to_table(serial_number, "serial_number")
    dict_to_table(model, "model")
end

function load_data(d)
    for i in filter(x->startswith(x,"20")&&endswith(x,".csv"),readdir(d))
        println(i)
        process_table("$(d)/$(i)")
    end
end


load_data("data")
