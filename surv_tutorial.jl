# Import Turing and Distributions.
using Turing, Distributions

# Import RDatasets.
using RDatasets

# Import MCMCChains, Plots, and StatsPlots for visualizations and diagnostics.
using MCMCChains, Plots, StatsPlots

# Functionality for splitting and normalizing the data
#using MLDataUtils: shuffleobs, stratifiedobs, rescale!

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
data[!,:EventNum]      = [r.Event ? 1.0 : 0.0 for r in eachrow(data)]
data[!,:MetastizedNum] = [r.Metastized == "yes" ? 1.0 : 0.0 for r in eachrow(data)]

# Delete the old columns which say "Yes" and "No".
select!(data, Not([:Metastized]))

# Show the first six rows of our edited dataset.
@info first(data, 6)

features = [:MetastizedNum,:EventNum]
target   = :Time

# Turing requires data in matrix form, not dataframe
train = Matrix(data[:, features])
train_label = data[:, target]


# Bayesian logistic regression (LR)
@model function survival_regression(x, y, σ)

    intercept ~ Normal(0, σ)
    metastized ~ Normal(0, σ)
    n,_=size(x)

    for i = 1:n
        θ = exp( intercept + metastized*x[i, 1] )
        dist = Exponential(θ)
        if x[i,2] == 1 # not-censored
            y[i] ~ dist
        else # censored
            pcensor = 1 - cdf(dist, y[i])
            1 ~ Bernoulli(pcensor)
        end
        
    end
end;

@info "train:$(size(train)) train_label:$(size(train_label))"


# Sample using HMC.
m = survival_regression(train, train_label, 1)
chain = sample(m, HMC(0.05, 10), MCMCThreads(), 2_000, 4)

@info describe(chain)

plot(chain)

savefig("surv_fig1.png")
