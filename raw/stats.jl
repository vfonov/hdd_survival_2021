using SQLite,DataFrames,Gadfly

conn = SQLite.DB("backblaze.sqlite3")


# select model_id,count(*) as cnt,avg(age) as mean_age from drive_surv group by 1  having cnt>100 order by 2

model = "ST12000NM0007"

model_id = (DBInterface.execute(conn,"select id from model where val=?",[model]) |> DataFrame ).id[1]

drive_surv = DBInterface.execute(conn,"select age,failure from drive_surv where model_id=?",[model_id])|>DataFrame


p = plot(drive_surv, x=:age, color=:failure, Theme(alphas=[0.6]),
    Stat.density(bandwidth=0.5), Geom.polygon(fill=true, preserve_order=true),
    Guide.colorkey(title="", pos=[2.5,0.6]), Guide.title("Kernel PDF")
)

p |> SVG("ages_$(model).svg",6inch,4inch)
