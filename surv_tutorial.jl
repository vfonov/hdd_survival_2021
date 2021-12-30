# Import Turing and Distributions.
using Turing, Distributions

# Import RDatasets.
using RDatasets

# Import MCMCChains, Plots, and StatsPlots for visualizations and diagnostics.
using MCMCChains, Plots, StatsPlots

# We need a logistic function, which is provided by StatsFuns.
using StatsFuns: logistic

# Functionality for splitting and normalizing the data
using MLDataUtils: shuffleobs, stratifiedobs, rescale!

using Logging

# Set a seed for reproducibility.
using Random
Random.seed!(0);

# Turn off progress monitor.
#Turing.setprogress!(false)

# Import the "Default" dataset.
data = RDatasets.dataset("HSAUR", "mastectomy");

# Show the first six rows of the dataset.
first(data, 6)

# Convert "Default" and "Student" to numeric values.
data[!,:EventNum]      = [r.Event ? 1.0 : 0.0 for r in eachrow(data)]
data[!,:MetastizedNum] = [r.Metastized == "yes" ? 1.0 : 0.0 for r in eachrow(data)]

# Delete the old columns which say "Yes" and "No".
select!(data, Not([:Metastized]))

# Show the first six rows of our edited dataset.
first(data, 6)

features = [:MetastizedNum,:EventNum]
target   = :Time

# Turing requires data in matrix form, not dataframe
train = Matrix(trainset[:, features])
train_label = trainset[:, target]


function  gumbel_sf(y,u,sigma)
    1.0-exp(-exp(-(y-u)/sigma))
end

# Bayesian logistic regression (LR)
@model function survival_regression(x, y, σ)

    intercept ~ Normal(0, σ)
    metastized ~ Normal(0, σ)

    s ~ Truncated(Normal(0,σ))
    #e ~ Gumbel(0,s)

    n=length(y)
    for i=eachindex(x)
        v = intercept + metastized*x[i, 1]
        if x[i,2] == 1
            # not-censored
            y[i] ~ Gumbel(v,s)
        else
            # censored
            y[i] ~ Bernoulli(gumbel_sf)
        end
        
    end
end;

# Retrieve the number of observations.
n, _ = size(train)

# Sample using HMC.
m = survival_regression(train, train_label, n, 1)
chain = sample(m, HMC(0.05, 10), MCMCThreads(), 2_000, 4)

describe(chain)

plot(chain)

savefig("fig1.png")
