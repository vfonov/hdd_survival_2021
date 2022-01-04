# Import Turing and Distributions.
using Turing, Distributions
#using Zygote
using Optim
using StatsBase
# Import RDatasets.
using RDatasets
using Survival
import Cairo, Fontconfig

# Import MCMCChains, Plots, and StatsPlots for visualizations and diagnostics.
using MCMCChains, Plots, StatsPlots

# Functionality for splitting and normalizing the data
using MLDataUtils: shuffleobs, stratifiedobs, rescale!

using Logging

# Set a seed for reproducibility.
using Random
Random.seed!(0);

# Turn off progress monitor.
Turing.setprogress!(false)
#Turing.setadbackend(:zygote)

# Import the "Default" dataset.
data = RDatasets.dataset("HSAUR", "mastectomy");

# Show the first six rows of the dataset.
# Convert "Default" and "Student" to numeric values.
data[!,:MetastizedNum] = [r.Metastized == "yes" ? 1.0 : 0.0 for r in eachrow(data)]
data[!,:LogTime] = log.(data.Time)
μ, σ = rescale!(data[!,:LogTime], obsdim=1)

# Delete the old columns which say "Yes" and "No".
#select!(data, Not([:Metastized,:Event]))

# Show the first six rows of our edited dataset.
@info first(data, 6)

features = [:MetastizedNum]
target   = :Time

# Turing requires data in matrix form, not dataframe
#train = Matrix(data[:, features])
#train_label = data[:, target]

#@info train
#@info train_label

@model function survival_regression(time, factor, event)
    #σ = 5
    σ ~ truncated(Normal(0, 100), 0, Inf)
    σ2 ~ truncated(Normal(0, 100), 0, Inf)

    intercept  ~ Normal(0, sqrt(σ))
    metastized ~ Normal(0, sqrt(σ))

    for i = eachindex(time)

        θ = intercept + metastized*factor[i]

        dist = Normal(θ, sqrt(σ2))
        if event[i] # not-censored
            time[i] ~ dist
        else # censored
            pcensor = ccdf(dist, time[i])
            1 ~ Bernoulli(pcensor)
        end
        
    end
end;

#@info "train:$(size(train)) train_label:$(size(train_label))"

# Sample using HMC.
# convert(Array{Float64,1}, data.Time)
model = survival_regression(data.LogTime, data.MetastizedNum, data.Event) # , 1.0,0.1
chain = sample(model, NUTS(0.65), MCMCThreads(), 4_000, 8)

@info describe(chain)

plot(chain)
savefig("surv_fig1.png")

# calculate mean predictions
intercept = mean(chain[:intercept])
metastized = mean(chain[:metastized])
@info "mean intercept:$(intercept) mean metastized:$(metastized)"

intercept = mode(chain[:intercept])
metastized = mode(chain[:metastized])
@info "mode intercept:$(intercept) mode metastized:$(metastized)"

@info "using MLE and MAP estimators"
# Generate a MLE estimate.
mle_estimate = optimize(model, MLE())
@info "MLE estimate"
@info mle_estimate.values
#@info coeftable(mle_estimate)

# Generate a MAP estimate.
# map_estimate = optimize(model, MAP())
# @info "MAP estimate"
# @info map_estimate.values
#@info coeftable(map_estimate)

# using weibull distribution
@model function survival_regression_weibull(time, factor, event)
    #σ = 5
    σ ~ truncated(Normal(0, 100), 0, Inf)

    scale      ~ truncated(Normal(0, 10), 0.0, Inf) # HACK
    intercept  ~ Normal(0, sqrt(σ))
    metastized ~ Normal(0, sqrt(σ))

    for i = eachindex(time)

        θ = intercept + metastized*factor[i]

        dist = Gumbel(θ, scale)
        if event[i] # not-censored
            time[i] ~ dist
        else # censored
            pcensor = ccdf(dist, time[i])
            1 ~ Bernoulli(pcensor)
        end
        
    end
end;


model2 = survival_regression_weibull(data.LogTime, data.MetastizedNum, data.Event) # , 1.0,0.1
chain2 = sample(model2, NUTS(0.65), MCMCThreads(), 4_000, 8)

@info describe(chain2)

plot(chain2)
savefig("surv_fig2.png")

# calculate mean predictions
intercept = mean(chain2[:intercept])
metastized = mean(chain2[:metastized])
scale = mean(chain2[:scale])
@info "mean intercept:$(intercept) mean metastized:$(metastized) mean scale:$scale"

# # Generate a MAP estimate.
# map_estimate2 = optimize(model2, MAP())
# @info "MAP estimate"
# @info map_estimate2.values

mle_estimate2 = optimize(model2, MLE())
@info "MLE estimate"
@info mle_estimate2.values
#c=coeftable(mle_estimate2)
@info mle_estimate2
