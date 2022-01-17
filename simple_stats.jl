using Gadfly
using DataFrames
using Logging
using Survival
import Cairo, Fontconfig

include("Backblaze.jl")
using .Backblaze

model = "ST12000NM0007"

drive_surv = backblaze_drive_surv(model)

f=fit(NelsonAalen, drive_surv.age, drive_surv.FAIL)

c=reinterpret(reshape,Float64,confint(f))

p = plot(x=f.times, y=f.chaz, ymin=c[1,:],ymax=c[2,:], Theme(alphas=[0.8]),
    Geom.line,Geom.ribbon
)

p |> PNG("ages_$(model).png",6inch,4inch)
