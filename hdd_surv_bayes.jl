# Import Turing and Distributions.
using Turing
using Distributions
using DataFrames
using Optim
using StatsBase
# Import RDatasets.
#using RDatasets
using Survival
import Cairo, Fontconfig

# Import MCMCChains, Plots, and StatsPlots for visualizations and diagnostics.
using MCMCChains, Plots, StatsPlots
gr() # plots backend

# Functionality for splitting and normalizing the data
using MLDataUtils: shuffleobs, stratifiedobs, rescale!

using Logging

# Set a seed for reproducibility.
using Random
Random.seed!(0);

# Turn off progress monitor.
Turing.setprogress!(true)
#Turing.setadbackend(:zygote)

include("Backblaze.jl")
using .Backblaze

model = "ST12000NM0007"
data = subset(backblaze_drive_surv(model),:age => ByRow(x->x>0))

data[!,:fage] = Float64.(data.age)
data[!,:log_age] = log.(data.age)
#μ, σ = rescale!(data[!,:LogTime], obsdim=1)
# Delete the old columns which say "Yes" and "No".
#select!(data, Not([:Metastized,:Event]))

# Show the first six rows of our edited dataset.
@info first(data, 6)

# Turing requires data in matrix form, not dataframe
#train = Matrix(data[:, features])
#train_label = data[:, target]


# using weibull distribution
@model function survival_regression_weibull(failed_time::Vector{Float64},censored_time::Vector{Float64})

    α ~ truncated(Normal(1.0, 2.0), 0.001, Inf) # HACK

    σ1 ~ truncated(Normal(0, 100), 0, Inf)
    θ ~ truncated(Normal(500, sqrt(σ1)), 0.001, Inf) # HACK

    for i = eachindex(failed_time)
        time_dist = Weibull(α, θ) #Gumbel(θ, scale)
        failed_time[i] ~ time_dist
    end

    for i = eachindex(censored_time)
        time_dist = Weibull(α, θ) #Gumbel(θ, scale)
        1 ~ Bernoulli(ccdf(time_dist, censored_time[i]))        
    end
    #return α, θ
end;

# using weibull distribution
@model function survival_regression_gumbel(log_failed_time::Vector{Float64},log_censored_time::Vector{Float64})

    θ ~ truncated(Normal(1.0, 2.0), 0.001, Inf) # HACK
    σ1 ~ truncated(Normal(0, 10), 0, Inf)
    μ ~ Normal(0, sqrt(σ1))

    for i = eachindex(log_failed_time)
        time_dist = Gumbel(μ, θ  )
        log_failed_time[i] ~ time_dist
    end

    for i = eachindex(log_censored_time)
        time_dist = Gumbel(μ, θ)
        1 ~ Bernoulli(ccdf(time_dist, log_censored_time[i]))        
    end
    #return α, θ
end;

# using logistic distribution
@model function survival_regression_logistic(log_failed_time::Vector{Float64},log_censored_time::Vector{Float64})

    θ ~ truncated(Normal(1.0, 2.0), 0.001, Inf) # HACK
    σ1 ~ truncated(Normal(0, 10), 0, Inf)
    μ ~ Normal(0, sqrt(σ1))

    for i = eachindex(log_failed_time)
        log_failed_time[i] ~ Logistic(μ, θ )
    end

    for i = eachindex(log_censored_time)
        1 ~ Bernoulli(ccdf(Logistic(μ, θ), log_censored_time[i]))        
    end
    #return α, θ
end;

#surv_model_weibull = survival_regression_weibull( subset(data,:FAIL).fage, subset(data,:FAIL=>ByRow(x->!x)).fage ) # , 1.0,0.1
surv_model_gumbell = survival_regression_gumbel( log.(subset(data,:FAIL).fage), log.(subset(data,:FAIL=>ByRow(x->!x)).fage) ) # , 1.0,0.1
surv_model_logistic = survival_regression_logistic( log.(subset(data,:FAIL).fage), log.(subset(data,:FAIL=>ByRow(x->!x)).fage) ) # , 1.0,0.1

if true
chain2 = sample(surv_model_gumbell, NUTS(0.65), MCMCThreads(), 1_000, 4)
summaries2, quantiles2 = describe(chain2);

@info summaries2

plot(chain2)
savefig("surv_fig2.png")

# calculate mean predictions
μ = mean(chain2[:μ])
θ = mean(chain2[:θ])
@info "mean μ:$(μ)  mean θ:$θ"
end

#initial estimate:
init_W=fit(Weibull,subset(data,:FAIL).fage)
@info "init_weibull:",init_W
#init_G=fit(Gumbel,log.(subset(data,:FAIL).fage))
#@info "init_gumbel:",init_G

# mle_estimate_weibull = optimize(surv_model_weibull,MAP())
# @info "MAP estimate Weibull"
# @info mle_estimate_weibull.values

mle_estimate_gumbel = optimize(surv_model_gumbell,MLE())
@info "MLE estimate gumbel"
@info mle_estimate_gumbel.values


mle_estimate_logistic = optimize(surv_model_logistic,MLE())
@info "MLE estimate logistic"
@info mle_estimate_logistic.values


# build K-M estimator
fit_km = fit(KaplanMeier, data.age, data.FAIL)
fit_km_c = reinterpret(reshape, Float64, confint(fit_km))

#@info "μ=$(mle_estimate_gumbel.values[:μ]), θ=$(mle_estimate_gumbel.values[:θ])"

#fit_weibull=ccdf.(init_W, fit_km.times)

# parametric fits
fit_gumbel=ccdf.(Gumbel(mle_estimate_gumbel.values[:μ], mle_estimate_gumbel.values[:θ]), log.(fit_km.times))
fit_logistic=ccdf.(Logistic(mle_estimate_logistic.values[:μ], mle_estimate_gumbel.values[:θ]), log.(fit_km.times))

plot(fit_km.times, fit_km.survival,linestyle = :solid,linewidth = 4,linecolor = :red, label="K-M",linealpha = 0.8,size=(1000,1000) )
plot!(fit_km.times,fit_km_c[1,:], linestyle = :dot,linecolor = :red,linealpha = 0.5)
plot!(fit_km.times,fit_km_c[2,:], linestyle = :dot,linecolor = :red,linealpha = 0.5)

plot!(fit_km.times, fit_gumbel,label="Gumbel",linestyle = :solid,linewidth = 4,linecolor = :green,linealpha = 0.8)

plot!(fit_km.times, fit_logistic,label="Logistic",linestyle = :solid,linewidth = 4,linecolor = :purple,linealpha = 0.8)

#plot!(fit_km.times, fit_weibull,label="Init Weibull",linestyle = :dash,linewidth = 4,linecolor = :blue,linealpha = 0.8)

savefig("surv_fig_weibull.png")
