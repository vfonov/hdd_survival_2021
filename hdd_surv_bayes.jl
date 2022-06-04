# Import Turing and Distributions.
using Turing
using Distributions
using DataFrames
using Optim
using StatsBase
using Survival
#import Cairo, Fontconfig

# Import MCMCChains, Plots, and StatsPlots for visualizations and diagnostics.
using MCMCChains, Plots, StatsPlots
gr() # plots backend

using Logging

# Set a seed for reproducibility.
using Random
Random.seed!(0);

# Turn off progress monitor.
Turing.setprogress!(true)

include("Backblaze.jl")
using .Backblaze

data = backblaze_drive_surv("ST4000DM000")

data[!,:log_age] = log.(data.age)
mean_log_age = mean(data[!,:log_age])
scale_log_age = std(data[!,:log_age])
data[!,:n_log_age] = (data.log_age .- mean_log_age) ./ scale_log_age

n_log_age_range=[minimum(data[!,:n_log_age] ),maximum(data[!,:n_log_age] )]


# run non-parametric method first Kaplan-Meier 
fit_km = fit(KaplanMeier, data.age, data.failure);
conf_km = reinterpret(reshape,Float64,confint(fit_km))


# Show the first six rows of our edited dataset.
@info first(data, 6)

# using weibull distribution
@model function survival_weibul(log_time, event)
    # priors 
    μ ~ Normal(0.0, 1.0)
	# prior scale
	θ ~ LogNormal(0.0,1.0) # truncated(Normal(0.0,5.0),0.0,Inf)
    # fitting data
    for i in eachindex(log_time)
        dist = Gumbel(μ, θ)
        if event[i] # not-censored
            log_time[i] ~ dist
        else # censored
            1 ~ Bernoulli(ccdf(dist, log_time[i]))
        end
    end
end;

# using log-logistic distribution
@model function survival_log_logistic(log_time, event)
    # priors 
    μ ~ Normal(0.0, 1.0)
	# prior scale
	θ ~ LogNormal(0.0,1.0) # truncated(Normal(0.0,5.0),0.0,Inf)
    # fitting data
    for i in eachindex(log_time)
        dist = Logistic(μ, θ)
        if event[i] # not-censored
            log_time[i] ~ dist
        else # censored
            1 ~ Bernoulli(ccdf(dist, log_time[i]))
        end
    end
end;


surv_model_weibull=survival_weibul( data.n_log_age, data.failure ) 
surv_model_log_logistic=survival_log_logistic( data.n_log_age, data.failure ) 


function simulate_survival_weibul(chain::Chains; sym=Symbol("μ"))
    # sample from chain

    # generate survival curves
    sim_range = LinRange(n_log_age_range[1], n_log_age_range[2], 100)

    fits = hcat( ( ccdf( Gumbel(μ, θ),sim_range ) for (μ, θ) in zip(chain[sym],chain[Symbol("θ")]) )... )

    return exp.(sim_range .* scale_log_age .+ mean_log_age), fits
end;

function simulate_survival_weibul(chain::ChainDataFrame; sym=Symbol("μ"))
    # sample from chain summary 

    # generate survival curves
    sim_range = LinRange(n_log_age_range[1], n_log_age_range[2], 100)

    fits = hcat( ( ccdf( Gumbel(μ, θ),sim_range ) for (μ, θ) in zip(chain[sym,:mean],chain[Symbol("θ"),:mean]) )... )

    return exp.(sim_range .* scale_log_age .+ mean_log_age), fits
end;

function simulate_survival_log_logistic(chain::Chains; sym=Symbol("μ"))
    # sample from chain

    # generate survival curves
    sim_range = LinRange(n_log_age_range[1], n_log_age_range[2], 100)

    fits = hcat( ( ccdf( Logistic(μ, θ),sim_range ) for (μ, θ) in zip(chain[sym],chain[Symbol("θ")]) )... )

    return exp.(sim_range .* scale_log_age .+ mean_log_age), fits
end;

function simulate_survival_log_logistic(chain::ChainDataFrame; sym=Symbol("μ"))
    # sample from chain summary 

    # generate survival curves
    sim_range = LinRange(n_log_age_range[1], n_log_age_range[2], 100)

    fits = hcat( ( ccdf( Logistic(μ, θ),sim_range ) for (μ, θ) in zip(chain[sym,:mean],chain[Symbol("θ"),:mean]) )... )

    return exp.(sim_range .* scale_log_age .+ mean_log_age), fits
end;


# simulate priors
sim_time_prior,sim_fit_prior = simulate_survival_weibul(sample(surv_model_weibull, Prior(), 1000));

# plot prior distribution
plot( sim_time_prior, sim_fit_prior, xlabel="Time", ylabel="Survival",title="Weibul Prior distribution", color=:gray,legend = false,alpha=0.1)
plot!(fit_km.times, fit_km.survival, label="K-M fit")

savefig("hdd_surv_prior.png")

chain_weibul = sample(surv_model_weibull, NUTS(0.65), MCMCThreads(), 2_000, 4)
#summaries2, quantiles2 = describe(chain_weibul);

plot(chain_weibul)
savefig("hdd_surv_chain_weibul.png")


chain_log_logistic = sample(surv_model_log_logistic, NUTS(0.65), MCMCThreads(), 2_000, 4)
#summaries2, quantiles2 = describe(chain_log_logistic);

plot(chain_log_logistic)
savefig("hdd_surv_chain_log_logistic.png")


# simulate distributions
sim_time_weibul_post,sim_fit_weibul_post=simulate_survival_weibul(sample(resetrange(chain_weibul), 1000),sym=Symbol("μ"))
sim_time_weibul_mean,sim_fit_weibul_mean=simulate_survival_weibul(mean(chain_weibul),sym=Symbol("μ"))

sim_time_log_logistic_post,sim_fit_log_logistic_post=simulate_survival_log_logistic(sample(resetrange(chain_log_logistic), 1000),sym=Symbol("μ"))
sim_time_log_logistic_mean,sim_fit_log_logistic_mean=simulate_survival_log_logistic(mean(chain_log_logistic),sym=Symbol("μ"))


plot( sim_time_weibul_post,sim_fit_weibul_post, xlabel="Time",ylabel="Survival",title="Posterior distribution",color=:green4,alpha=0.05,label="")
plot!(sim_time_weibul_mean,sim_fit_weibul_mean,color=:green, label="Weibul")


plot!(sim_time_log_logistic_post,sim_fit_log_logistic_post,color=:red4,alpha=0.05,label="")
plot!(sim_time_log_logistic_mean,sim_fit_log_logistic_mean,color=:red,label="Log-Logistic")

plot!(fit_km.times, fit_km.survival,label="K-M fit",color=:blue,linestyle=:dot,lw=2)
plot!(fit_km.times, conf_km[1,:],label="",color=:blue4,linestyle=:dot,lw=1)
plot!(fit_km.times, conf_km[2,:],label="",color=:blue4,linestyle=:dot,lw=1)

savefig("hdd_surv_posterior.png")
