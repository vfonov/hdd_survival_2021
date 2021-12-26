using Gadfly
using DataFrames
using Logging

include("Backblaze.jl")
using .Backblaze

model = "ST12000NM0007"

drive_surv = backblaze_drive_surv(model)

@info names(drive_surv)

p = plot(drive_surv, x=:age, color=:FAIL, Theme(alphas=[0.8]),
    Stat.density(bandwidth=0.5)
)

p |> PNG("ages_$(model).png",6inch,4inch)
