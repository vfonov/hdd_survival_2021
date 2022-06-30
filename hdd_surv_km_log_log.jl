# Import Turing and Distributions.
#using Turing
#using Distributions
using DataFrames,CategoricalArrays
#using Optim
using StatsBase
using Survival
#using SplitApplyCombine

# Import MCMCChains, Plots, and StatsPlots for visualizations and diagnostics.
#using MCMCChains

using Gadfly, Compose, Colors


using Logging

# Set a seed for reproducibility.
using Random
Random.seed!(0);

# Turn off progress monitor.
#Turing.setprogress!(true)

include("Backblaze.jl")
using .Backblaze

const n_model = 10

models = first(model_stats(),n_model)

data = vcat( [ insertcols!(backblaze_drive_surv(m),:model=>m) for m in models.model]... )
data.model=categorical(data.model)

data[!,:log_age] = log.(data.age)
mean_log_age = mean(data[!,:log_age])
scale_log_age = std(data[!,:log_age])
data[!,:n_log_age] = (data.log_age .- mean_log_age) ./ scale_log_age

n_log_age_range=[minimum(data[!,:n_log_age] ),maximum(data[!,:n_log_age] )]

km_stats=DataFrame( times=Float64[],
                    surv=Float64[],
                    surv_log_log=Float64[], 
                    surv_logistic=Float64[],
                    log_times=Float64[],
                    model=String[])

for i in 1:n_model
    model=levels(data.model)[i]
    ss=filter(:model=>(x->x==model),data)
    # run non-parametric method first Kaplan-Meier 
    fit_km = fit(KaplanMeier, ss.age, ss.failure);
    #conf_na = reinterpret(reshape, Float64, confint(fit_na))

    global km_stats=vcat(km_stats,
        DataFrame(times         = fit_km.times/365, 
                  surv          = fit_km.survival, 
                  surv_log_log  = log.(-1.0 .* log.(fit_km.survival)),
                  surv_logistic = log.( (1.0 .- fit_km.survival) ./ fit_km.survival),
                  log_times     = log.(fit_km.times/365), 
                  model         = repeat([model],length(fit_km.survival))))
end

# plot all km graphs

plot(km_stats, x=:times, y=:surv, color=:model, 
       Geom.line,style(line_width=2mm, line_style=[:dash]),
       Theme(background_color="white",
       key_position=:inside)) |> SVG("hdd_top$(n_model)_km_fit.svg", 20cm, 20cm)


plot(km_stats, x=:log_times, y=:surv_log_log, color=:model, 
       Geom.line,style(line_width=2mm, line_style=[:dash]),
       Theme(background_color="white",
       key_position=:inside)) |> SVG("hdd_top$(n_model)_km_fit_log_log.svg", 20cm, 20cm)

plot(km_stats, x=:log_times, y=:surv_logistic, color=:model, 
       Geom.line,style(line_width=2mm, line_style=[:dash]),
       Theme(background_color="white",
       key_position=:inside)) |> SVG("hdd_top$(n_model)_km_fit_logistic.svg", 20cm, 20cm)
