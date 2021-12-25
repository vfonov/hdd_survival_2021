using SQLite,DataFrames,Gadfly

conn = SQLite.DB("backblaze.sqlite3")


# select model_id,count(*) as cnt,avg(age) as mean_age from drive_surv group by 1  having cnt>100 order by 2

model = "ST12000NM0007"

model_id = (DBInterface.execute(conn,"select id from model where val=?",[model]) |> DataFrame ).id[1]

drive_surv = DBInterface.execute(conn,"select age,failure from drive_surv where model_id=?",[model_id])|>DataFrame

transform!(drive_surv,:failure => categorical -> :FAIL)

# Geom.polygon(fill=true, preserve_order=true)

p = plot(drive_surv, x=:age, color=:FAIL, Theme(alphas=[0.8]),
    Stat.density(bandwidth=0.5)
)

p |> SVG("ages_$(model).svg",6inch,4inch)
