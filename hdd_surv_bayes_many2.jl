# Import Turing and Distributions.
using Turing
using Distributions
using DataFrames,CategoricalArrays
using Optim
using StatsBase
using Survival
using SplitApplyCombine

# Import MCMCChains, Plots, and StatsPlots for visualizations and diagnostics.
using MCMCChains

using Gadfly, Compose, Colors


using Logging

# Set a seed for reproducibility.
using Random
Random.seed!(0);

# Turn off progress monitor.
Turing.setprogress!(true)

include("Backblaze.jl")
using .Backblaze

const n_model = 8

models = first(model_stats(),n_model)

data = vcat( [ insertcols!(backblaze_drive_surv(m),:model=>m) for m in models.model]... )
data.model=categorical(data.model)

data[!,:log_age] = log.(data.age)
mean_log_age = mean(data[!,:log_age])
scale_log_age = std(data[!,:log_age])
data[!,:n_log_age] = (data.log_age .- mean_log_age) ./ scale_log_age

n_log_age_range=[minimum(data[!,:n_log_age] ),maximum(data[!,:n_log_age] )]

km_stats=DataFrame(times=Float64[],surv=Float64[],model=String[])

for i in 1:n_model
    model=levels(data.model)[i]
    ss=filter(:model=>(x->x==model),data)
    # run non-parametric method first Kaplan-Meier 
    fit_km = fit(KaplanMeier, ss.age, ss.failure);
    #conf_na = reinterpret(reshape, Float64, confint(fit_na))

    global km_stats=vcat(km_stats,
        DataFrame(times=fit_km.times/365, surv=fit_km.survival, model=repeat([model],length(fit_km.survival))))
end

# plot all km graphs

plot(km_stats, x=:times, y=:surv, color=:model, 
       Geom.line,style(line_width=2mm, line_style=[:dash]),
       Theme(background_color="white",
       key_position=:inside)) |> SVG("hdd_multi_km_fit.svg", 15cm, 15cm)



# run non-parametric method first Kaplan-Meier 
#fit_km = fit(KaplanMeier, data.age, data.failure);
#conf_km = reinterpret(reshape,Float64,confint(fit_km))


# Show the first six rows of our edited dataset.
@info first(data, 6)

# using loglogistic distribution
@model function survival_loglogistic(log_time::Vector{Float64}, event::Vector{Bool}, hdd_model::Vector{Int64})
    # priors 
    μ ~ MvNormal( zeros(n_model), 1.0)
	# prior scale
	θ ~ LogNormal(0.0, 1.0) # truncated(Normal(0.0,5.0),0.0,Inf) MvLogNormal ?
    # fitting data
    for i in eachindex(log_time)
        dist = Logistic(μ[hdd_model[i]], θ)
        if event[i] # not-censored
            log_time[i] ~ dist
        else # censored
            1 ~ Bernoulli(ccdf(dist, log_time[i]))
        end
    end
end;

surv_model_loglogistic=survival_loglogistic( data.n_log_age, data.failure, levelcode.(data.model) ) 

function simulate_survival_loglogistic(chain::Chains; sym="μ[1]",p=5)
    # sample from chain, times are in years
    # extract percntiles : p , 50, 100-p

    # generate survival curves
    sim_range = LinRange(n_log_age_range[1], n_log_age_range[2], 100)

    sims = hcat( 
        (ccdf( Logistic(μ, θ), sim_range )  for (μ, θ) in zip(chain[sym], chain[Symbol("θ")]) )...
    )

    # extract percentile
    p1 = percentile.(splitdims(sims, 1), p)
    pm = percentile.(splitdims(sims, 1), 50)
    p2 = percentile.(splitdims(sims, 1), 100-p)

    DataFrame(  surv_p1=p1,
                surv=pm,
                surv_p2=p2, 
                times=exp.(sim_range .* scale_log_age .+ mean_log_age)./365 
                )
end;

function simulate_survival_loglogistic(chain::ChainDataFrame; sym="μ[1]")
    # sample from chain summary # TODO: fix this to not epect multiple sims?

    # generate survival curves
    sim_range = LinRange(n_log_age_range[1], n_log_age_range[2], 100)

    vcat( ( DataFrame(  surv=ccdf( Logistic(μ, θ), sim_range ), 
                        times=exp.(sim_range .* scale_log_age .+ mean_log_age) ./ 365,
                        sim=fill(s,length(sim_range)) )
                        for (s,(μ, θ)) in enumerate(zip(chain[sym,:mean], chain[Symbol("θ"),:mean])) )... )
end;

# simulate priors
@info "Building prior sample"
sim_loglogistic_prior = simulate_survival_loglogistic(sample(surv_model_loglogistic, Prior(), 1000));

# plot prior distribution
plot( sim_loglogistic_prior, x=:times, y=:surv, ymin=:surv_p1,ymax=:surv_p2, Geom.line, Geom.ribbon, alpha=[0.6],
        Theme(background_color="white")) |>  # ,default_color=RGBA(0.1,0.1,0.1,0.1)
        SVG("hdd_multi_loglogistic_prior.svg", 15cm, 15cm)

@info "Running sampler"
chain_loglogistic = sample(surv_model_loglogistic, NUTS(0.65), MCMCThreads(), 1_000, 4)
#summaries2, quantiles2 = describe(chain_loglogistic);
#df = DataFrame(chain_loglogistic)
#df[!, :chain] = categorical(df.chain)

# plot(first_chain, ygroup=:parameter, x=:iteration, y=:value, color=:chain,
#     Geom.subplot_grid(Geom.point), Guide.ylabel("Sample value"))

# plot(df, x=:A, color=:chain, 
#     Geom.density, Guide.ylabel("Density"),Theme(background_color="white")) |> 
#     SVG("hdd_multi_surv_chain_loglogistic.svg", 15cm, 15cm)

# simulate distributions
sim_loglogistic_post=vcat( ( 
    insertcols!( simulate_survival_loglogistic(sample(resetrange(chain_loglogistic), 1000), sym="μ[$i]"), :model=> levels(data.model)[i])
    for i in 1:n_model)...)

# sim_loglogistic_post_mean = vcat( ( 
#     insertcols!( simulate_survival_loglogistic(mean(chain_loglogistic),sym="μ[$i]"), :model=> levels(data.model)[i]) 
#         for i in 1:n_model)...)

l1=layer(sim_loglogistic_post, 
         x=:times, y=:surv, 
         Geom.line, 
         color=:model)

l2=layer(sim_loglogistic_post, 
         x=:times,
         ymin=:surv_p1, ymax=:surv_p2, 
         Geom.ribbon,color=:model)

l3=layer(km_stats, x=:times, y=:surv, 
         color=:model, 
         Geom.line, style(line_style=[:dash]))

plot( l1, l2, l3,
    Guide.colorkey(title="HDD model"),
    Theme(background_color="white",key_position=:inside,alphas=[0.6]) ) |>
    SVG("hdd_multi_loglogistic_posterior.svg", 15cm, 15cm)
