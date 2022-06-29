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

const n_model = 1
const n_comp = 2

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
       key_position=:inside)) |> SVG("hdd_mix_km_fit.svg", 15cm, 15cm)

# run non-parametric method first Kaplan-Meier 
#fit_km = fit(KaplanMeier, data.age, data.failure);
#conf_km = reinterpret(reshape,Float64,confint(fit_km))


# Show the first six rows of our edited dataset.
@info first(data, 6)

# using mix distribution
@model function survival_mix(log_time::Vector{Float64}, event::Vector{Bool}, hdd_model::Vector{Int64})
    # priors
    μ_bar=0.0
    σ_bar=1.0
    θ_bar=0.0
    σ2_bar=1.0

    μ1 ~ filldist( Normal(μ_bar, σ_bar), n_model)
    μ2 ~ filldist( Normal(μ_bar, σ_bar), n_model)
	# prior scale
	θ1 ~ filldist( LogNormal(θ_bar, σ2_bar),n_model) 
	θ2 ~ filldist( LogNormal(θ_bar, σ2_bar),n_model) 
    # fitting data
    for i in eachindex(log_time)
        #dist1 = Gumbel(μ1[hdd_model[i]],θ1[hdd_model[i]])
        #dist2 = Gumbel(μ2[hdd_model[i]],θ2[hdd_model[i]]) 
        dist = MixtureModel(Gumbel[
            Gumbel(μ1[hdd_model[i]],θ1[hdd_model[i]]),
            Gumbel(μ2[hdd_model[i]],θ2[hdd_model[i]]) ])

        if event[i] # not-censored
            #log_time[i] ~ dist1
            #log_time[i] ~ dist2
            log_time[i] ~ dist
        else # censored
            # HACK : ?
            #1 ~ Bernoulli(ccdf(dist1, log_time[i]))
            #1 ~ Bernoulli(ccdf(dist2, log_time[i]))
            1 ~ Bernoulli(ccdf(dist, log_time[i]))
        end
    end
end;

surv_model_mix=survival_mix( data.n_log_age, data.failure, levelcode.(data.model) ) 

function simulate_survival_mix(chain::Chains; μ1="μ1[1]",θ1="θ1[1]",μ2="μ2[1]",θ2="θ2[2]",p=5)
    # sample from chain, times are in years
    # extract percntiles : p , 50, 100-p

    # generate survival curves
    sim_range = LinRange(n_log_age_range[1], n_log_age_range[2], 100)

    # TODO: change to the mixture of two gumbel
    sims = hcat( 
        (ccdf( Gumbel(μ1, θ1), sim_range )  for (μ1, θ1) in zip(chain[μ1], chain[θ1]) )...
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

# simulate priors
@info "Building prior sample"
sim_mix_prior = simulate_survival_mix(sample(surv_model_mix, Prior(), 1000));

# plot prior distribution
plot( sim_mix_prior, x=:times, y=:surv, ymin=:surv_p1,ymax=:surv_p2, Geom.line, Geom.ribbon, alpha=[0.6],
        Theme(background_color="white")) |>  # ,default_color=RGBA(0.1,0.1,0.1,0.1)
        SVG("hdd_mix_mix_prior.svg", 15cm, 15cm)

@info "Running sampler"
chain_mix = sample(surv_model_mix, NUTS(0.65), MCMCThreads(), 1_000, 4)
summaries, quantiles = describe(chain_mix);
@info "Summaries:"
show(IOContext(stdout, :limit => false), "text/plain",summaries)
show(IOContext(stdout, :limit => false), "text/plain",quantiles)
#df = DataFrame(chain_mix)
#df[!, :chain] = categorical(df.chain)

# plot(first_chain, ygroup=:parameter, x=:iteration, y=:value, color=:chain,
#     Geom.subplot_grid(Geom.point), Guide.ylabel("Sample value"))

# plot(df, x=:A, color=:chain, 
#     Geom.density, Guide.ylabel("Density"),Theme(background_color="white")) |> 
#     SVG("hdd_multi_surv_chain_mix.svg", 15cm, 15cm)

# simulate distributions
sim_mix_post=vcat( ( 
    insertcols!( simulate_survival_mix(sample(resetrange(chain_mix), 1000), 
                μ1="μ1[$i]",θ1="θ1[$i]", μ2="μ2[$i]",θ2="θ2[$i]"), :model=> levels(data.model)[i])
    for i in 1:n_model)...)

# sim_mix_post_mean = vcat( ( 
#     insertcols!( simulate_survival_mix(mean(chain_mix),sym="μ[$i]"), :model=> levels(data.model)[i]) 
#         for i in 1:n_model)...)

l1=layer(sim_mix_post, 
         x=:times, y=:surv, 
         Geom.line, 
         color=:model)

l2=layer(sim_mix_post, 
         x=:times,
         ymin=:surv_p1, ymax=:surv_p2, 
         Geom.ribbon,color=:model)

l3=layer(km_stats, x=:times, y=:surv, 
         color=:model, 
         Geom.line, style(line_style=[:dash]))

plot( l1, l2, l3,
    Guide.colorkey(title="HDD model"),
    Theme(background_color="white",key_position=:inside,alphas=[0.6]) ) |>
    SVG("hdd_mix_mix_posterior_full.svg", 15cm, 15cm)
