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

@model function survival_regression(log_time, factor, event)
    #σ = 5
    σ ~ truncated(Normal(0, 100), 0, Inf)
    σ2 ~ truncated(Normal(0, 100), 0, Inf)

    intercept  ~ Normal(0, sqrt(σ))
    metastized ~ Normal(0, sqrt(σ))

    for i = eachindex(log_time)

        θ = intercept + metastized*factor[i]

        dist = Normal(θ, sqrt(σ2))
        if event[i] # not-censored
            log_time[i] ~ dist
        else # censored
            1 ~ Bernoulli(ccdf(dist, log_time[i]))
        end
        
    end
end;

#@info "train:$(size(train)) train_label:$(size(train_label))"

# Sample using HMC.
# convert(Array{Float64,1}, data.Time)
model = survival_regression(data.LogTime, data.MetastizedNum, data.Event) # , 1.0,0.1
chain = sample(model, NUTS(0.65), MCMCThreads(), 2_000, 4)
summaries, quantiles = describe(chain);

@info summaries

plot(chain)
savefig("surv_fig1.png")

# calculate mean predictions
intercept_exp  = mean(chain[:intercept])
metastized_exp = mean(chain[:metastized])
@info "mean intercept:$(intercept_exp) $(size(chain[:intercept])) mean metastized:$(metastized_exp)"

# Generate a MLE estimate.
mle_estimate = optimize(model, MLE())
@info "MLE estimate"
@info mle_estimate.values
#@info coeftable(mle_estimate)


# using weibull distribution
@model function survival_regression_weibull(log_time, factor, event)
    σ1 ~ truncated(Normal(0, 100), 0, Inf)
    σ2 ~ truncated(Normal(0, 100), 0, Inf)

    scale      ~ truncated(Normal(0, 10), 0.0, Inf) # HACK
    intercept  ~ Normal(0, sqrt(σ1))
    metastized ~ Normal(0, sqrt(σ2))

    for i = eachindex(log_time)
        # accceleration facctor
        θ = intercept + metastized*factor[i]

        time_dist = Gumbel(θ, scale)
        if event[i] # not-censored
            log_time[i] ~ time_dist
        else # censored
            1 ~ Bernoulli(ccdf(time_dist, log_time[i]))
        end
        
    end
end;


model2 = survival_regression_weibull(data.LogTime, data.MetastizedNum, data.Event) # , 1.0,0.1
chain2 = sample(model2, NUTS(0.65), MCMCThreads(), 2_000, 4)
summaries2, quantiles2 = describe(chain2);

@info summaries2

plot(chain2)
savefig("surv_fig2.png")

# calculate mean predictions
intercept = mean(chain2[:intercept])
metastized = mean(chain2[:metastized])
scale = mean(chain2[:scale])
@info "mean intercept:$(intercept) mean metastized:$(metastized) mean scale:$scale"

mle_estimate2 = optimize(model2, MLE())
@info "MLE estimate"
@info mle_estimate2.values
@info mle_estimate2
#c=coeftable(mle_estimate2)
#@info describe(mle_estimate2)

# build K-M estimator
fit_km = fit(KaplanMeier, data.Time, data.Event)
fit_km_c = reinterpret(reshape, Float64, confint(fit_km))
log_times = log.(fit_km.times)
rescale!(log_times, μ, σ)

fit_weibull=exp.( - exp.(intercept_exp .+ log_times ) )

# perform posterior and prior predictive checks on the models

plot(fit_km.times, fit_km.survival)
plot!(fit_km.times, pred_weib_1)
savefig("surv_fig3.png")

# p1 = plot(x=fit_km.times, y=fit_km.survival, ymin=fit_km_c[1,:], ymax=fit_km_c[2,:],color="green",
#     Geom.line, Geom.ribbon
# )
# p2 = plot(x=fit_km.times, y=pred_weib_1,color="red",
#     Geom.line
# )

#vstack(p1,p2) |> PNG("surv_fig3.png",6inch,4inch)
