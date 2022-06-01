# Import Turing and Distributions.
using Turing, Distributions
using Optim
using StatsBase
using RDatasets
using Survival
import Cairo, Fontconfig

# Import MCMCChains, Plots, and StatsPlots for visualizations and diagnostics.
using MCMCChains, Plots, StatsPlots

# Functionality for splitting and normalizing the data
#using MLUtils: shuffleobs, stratifiedobs, rescale!

using Logging

# Set a seed for reproducibility.
using Random
Random.seed!(0);

# Turn off progress monitor.
#Turing.setprogress!(false)

# Import the "Default" dataset.
data = RDatasets.dataset("HSAUR", "mastectomy");

# Show the first six rows of the dataset.
# Convert "Default" and "Student" to numeric values.
data[!,:MetastizedNum] = [r.Metastized == "yes" ? 2 : 1 for r in eachrow(data)]
data[!,:LogTime] = log.(data.Time)

#μ, σ = rescale!(data[!,:LogTime], obsdim=1)
log_time_scale = 1.0/ maximum(data[!,:LogTime])
data[!,:LogTimeS] = data[!,:LogTime]*log_time_scale

# Delete the old columns which say "Yes" and "No".
#select!(data, Not([:Metastized,:Event]))

# Show the first six rows of our edited dataset.
@info first(data, 6)

# build non-parametric K-M estimator
fit_km_1 = fit(KaplanMeier, data.Time[data.MetastizedNum.==1], data.Event[data.MetastizedNum.==1])
#fit_km_1_c = reinterpret(reshape, Float64, confint(fit_km_1))

fit_km_2 = fit(KaplanMeier, data.Time[data.MetastizedNum.==2], data.Event[data.MetastizedNum.==2])
#fit_km_2_c = reinterpret(reshape, Float64, confint(fit_km_2))


plot(fit_km_1.times, fit_km_1.survival)#fit_km_c[1,:], ymax=fit_km_c[2,:]
plot!(fit_km_2.times, fit_km_2.survival)
#plot!(fit_km.times, pred_weib_1)
savefig("surv_km.png")


# log-normal model
@model function survival_lognormal(log_time, MetastizedNum, event)
    # priors
    #σ ~ LogNormal(0,1)
    σ ~ Exponential(2)
    metastized ~ MvNormal([0, 0], 1.0)

    # fitting data
    for i in eachindex(log_time)
        θ = metastized[MetastizedNum[i]]

        dist = Normal(θ, σ)
        if event[i] # not-censored
            log_time[i] ~ dist
        else # censored
            1 ~ Bernoulli(ccdf(dist, log_time[i]))
        end
        
    end
    return log_time
end;

model = survival_lognormal(data.LogTimeS, data.MetastizedNum, data.Event) # , 1.0,0.1

function simulate_survival_lognorm(chain::Chains, sym=Symbol("metastized[1]"))
    # sample from chain

    # generate survival curves
    sim_range = LinRange(minimum(data.LogTimeS), maximum(data.LogTimeS)*1.1, 20)

    fits = hcat( ( ccdf( Normal(θ, σ),sim_range ) for (θ, σ) in zip(chain[sym],chain[Symbol("σ")]) )... )

    return exp.(sim_range ./ log_time_scale), fits
end

function simulate_survival_lognorm(chain::ChainDataFrame,sym=Symbol("metastized[1]"))
    # sample from chain summary 

    # generate survival curves
    sim_range = LinRange(minimum(data.LogTimeS), maximum(data.LogTimeS)*1.1, 20)

    fits = hcat( ( ccdf( Normal(θ, σ),sim_range ) for (θ, σ) in zip(chain[sym,:mean],chain[Symbol("σ"),:mean]) )... )

    return exp.(sim_range ./ log_time_scale), fits
end

begin
    sim_time,sim_fit=simulate_survival_lognorm(sample(model, Prior(), 1000))


    plot( sim_time, sim_fit, xlabel="Time",ylabel="Survival",title="Prior distribution",color=:gray,legend = false,alpha=0.1)
    savefig("surv_priors_lognorm.png")
end

begin
    # Sample using HMC.
    chain = sample(model, NUTS(0.65), MCMCThreads(), 1_000, 4)
    summaries, quantiles = describe(chain);
    show(IOContext(stdout, :limit => false), "text/plain",summaries)

    plot(chain)
    savefig("surv_chain1.png")
end

begin

    sim_time,sim_fit=simulate_survival(sample(resetrange(chain), 1000))

    sim_time_mean1,sim_fit_mean1=simulate_survival_lognorm(mean(chain),Symbol("metastized[1]"))
    sim_time_mean2,sim_fit_mean2=simulate_survival_lognorm(mean(chain),Symbol("metastized[2]"))

    plot( sim_time, sim_fit, xlabel="Time",ylabel="Survival",title="Posterior distribution",color=:gray,legend = false,alpha=0.1)
    plot!(sim_time_mean1,sim_fit_mean1,color=:blue )
    plot!(sim_time_mean2,sim_fit_mean2,color=:red )

    savefig("surv_posterior_lognorm.png")
end

mle_estimate = optimize(model, MLE())
@info "MLE estimate"
@info mle_estimate.values

# using weibull distribution, with different scale
@model function survival_regression_weibull(log_time, MetastizedNum, event)
    # priors
    metastized ~ MvNormal([0, 0], 1.0)
    metastized_scale ~ MvLogNormal([0, 0], 1.0)

    for i = eachindex(log_time)
        # accceleration factor
        θ     = metastized[MetastizedNum[i]]
        scale = metastized_scale[MetastizedNum[i]]

        time_dist = Gumbel(θ, scale)
        if event[i] # not-censored
            log_time[i] ~ time_dist
        else # censored
            1 ~ Bernoulli(ccdf(time_dist, log_time[i]))
        end
        
    end
end;

model2 = survival_regression_weibull(data.LogTimeS, data.MetastizedNum, data.Event) # , 1.0,0.1
chain2 = sample(model2, NUTS(0.65), MCMCThreads(), 1_000, 4)
summaries2, quantiles2 = describe(chain2);

@info summaries2

plot(chain2)
savefig("surv_chain2.png")

@info mean(chain[Symbol("metastized[1]")]),mean(chain[Symbol("metastized[2]")])
@info mean(chain[Symbol("metastized_scale[1]")]),mean(chain[Symbol("metastized_scale[2]")])

mle_estimate2 = optimize(model2, MLE())
@info "MLE estimate"
@info mle_estimate2.values
@info mle_estimate2

# perform posterior and prior predictive checks on the models

savefig("surv_fig3.png")

# p1 = plot(x=fit_km.times, y=fit_km.survival, ymin=fit_km_c[1,:], ymax=fit_km_c[2,:],color="green",
#     Geom.line, Geom.ribbon
# )
# p2 = plot(x=fit_km.times, y=pred_weib_1,color="red",
#     Geom.line
# )

#vstack(p1,p2) |> PNG("surv_fig3.png",6inch,4inch)
