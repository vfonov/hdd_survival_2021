using DataFrames,CategoricalArrays
using StatsBase
using Survival
using Interpolations

using Gadfly, Compose, Colors


using Logging

# Set a seed for reproducibility.
using Random
Random.seed!(0);

# Turn off progress monitor.
#Turing.setprogress!(true)

include("Backblaze.jl")
using .Backblaze

const n_model = 3

models = first(model_stats(),n_model)

data = vcat( [ insertcols!(backblaze_drive_surv(m),:model=>m) for m in models.model]... )
data.model=categorical(data.model)

data[!,:log_age] = log.(data.age)
mean_log_age = mean(data[!,:log_age])
scale_log_age = std(data[!,:log_age])
data[!,:n_log_age] = (data.log_age .- mean_log_age) ./ scale_log_age

n_log_age_range=[minimum(data[!,:n_log_age] ),maximum(data[!,:n_log_age] )]

na_stats_=[]

interp=Gridded(Linear())

for i in 1:n_model
    model=levels(data.model)[i]
    ss=filter(:model=>(x->x==model),data)
    # run non-parametric method first Kaplan-Meier 
    fit_na = fit(NelsonAalen, ss.age, ss.failure);
    #conf_na = reinterpret(reshape, Float64, confint(fit_na))
    times         = fit_na.times/365
       
    itp=extrapolate(interpolate((times,), fit_na.chaz, interp),Flat())
    # will produce StaticArrays.SVector{1}
    grad=[clamp(gradient(itp,t)[1],0,2) for t in times]
 
    push!(na_stats_,
        DataFrame(times         = times, 
                  chaz          = fit_na.chaz,
                  chaz_g        = grad, 
                  log_times     = log.(times), 
                  model         = repeat([model],length(times))))
end
na_stats=vcat(na_stats_...)
# plot all km graphs

plot(na_stats, x=:times, y=:chaz, color=:model, 
       Geom.line,style(line_width=2mm, line_style=[:dash]),
       Theme(background_color="white",
       key_position=:inside)) |> SVG("hdd_top$(n_model)_na_fit.svg", 20cm, 20cm)

plot(na_stats, x=:times, y=:chaz_g, color=:model, 
       Geom.line,style(line_width=2mm, line_style=[:dash]),
       Theme(background_color="white",
       key_position=:inside)) |> SVG("hdd_top$(n_model)_na_fit_g.svg", 20cm, 20cm)
