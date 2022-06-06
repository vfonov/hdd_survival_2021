using Distributions
using DataFrames
using StatsBase
using Survival
using CategoricalArrays
#import Cairo, Fontconfig
using Gadfly, Compose

using Logging

# Set a seed for reproducibility.
using Random
Random.seed!(0);

include("Backblaze.jl")
using .Backblaze


# select models with highest counts

models = first(model_stats(),10)
na_stats=DataFrame(times=Float64[],chaz=Float64[],chaz_lo=Float64[],chaz_hi=Float64[],model=String[])


for m in eachrow(models)

    data = backblaze_drive_surv(m.model)

    # run non-parametric method first Kaplan-Meier 
    fit_na = fit(NelsonAalen, data.age, data.failure);
    conf_na = reinterpret(reshape, Float64, confint(fit_na))

    global na_stats=vcat(na_stats,
        DataFrame(times=fit_na.times/365,chaz=fit_na.chaz,chaz_lo=conf_na[1,:],chaz_hi=conf_na[2,:],model=repeat([m.model],length(fit_na.chaz))))
end



@info na_stats

p=plot(na_stats, x=:times, y=:chaz, color=:model, 
       Geom.line,
       Theme(background_color="white",
       key_position=:inside))

p|>SVG("na_top10.svg", 15cm, 15cm)
