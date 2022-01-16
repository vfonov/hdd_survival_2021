using DataFrames
using Distributions
using Logging
using Statistics
#using Bootstrap
using ProgressBars

using Gadfly
import Cairo, Fontconfig
using Survival


include("Backblaze.jl")
using .Backblaze

model = "ST12000NM0007"
drive_surv_1 = backblaze_drive_surv(model)
model = "ST12000NM0008"
drive_surv_2 = backblaze_drive_surv(model)
model = "ST12000NM001G"
drive_surv_3 = backblaze_drive_surv(model)

drive_surv = vcat(drive_surv_1,drive_surv_2,drive_surv_3)
model = "ST12000"

@info "Sorting to speedup ?"
sort!(drive_surv,[:age])


failed_drive_surv = subset(drive_surv,:failure => ByRow(x->x==1))
censored_drive_surv = subset(drive_surv,:failure => ByRow(x->x==0))

global_max_age = drive_surv.age[end]# should be sorted

@info "Maximum drive age:$(global_max_age/365)y N=$(nrow(drive_surv)) Nfail=$(nrow(failed_drive_surv))"
@info "Median failed age:$(median(failed_drive_surv.age)/365)y"
@info "Median censored age:$(median(censored_drive_surv.age)/365)y"


mutable struct check_result
    fail::Bool
    fail_day::Int64
    n_rebuild::Int64

    function check_result(fail=false,fail_day=0,n_rebuild=0) 
        new(fail,fail_day,n_rebuild)
    end
end



# return (n_fail,n_rebuild)
function check_fail(s::DataFrame, n_raid::Int64, time_window::Int64)::check_result
    # return (failed,age,n_rebuid)
    censored::Vector{Int64} = subset(s,:failure => ByRow(x-> x == 0)).age
    min_censored_age::Int64 = global_max_age

    if length(censored)>0
        min_censored_age = censored[1]
    end
    result = check_result()

    failed::Vector{Int64} = subset(s,:failure => ByRow(x->x==1), :age => ByRow(x-> x<= min_censored_age)).age
    n_rebuild::Integer = length(failed)

    if n_rebuild == 0
        return check_result(false, min_censored_age, 0)
    elseif  n_rebuild <= n_raid
        return check_result(false, min_censored_age, n_rebuild)
    else
        fail::Bool = 0
        fail_day = failed[1]
        
        for n=1:(n_rebuild-n_raid)
            if (failed[n+n_raid]-failed[n]) <= time_window
                fail = 1
                fail_day = failed[n+n_raid]
                break
            end
        end
        return check_result(fail, fail_day, n_rebuild)
    end
end


function simulate_raid(drive_surv, n_samples::Integer, n_pools::Integer, n_drives::Integer, n_raid::Integer, time_window::Integer) 
    results = DataFrame(failed=zeros(Bool, n_samples), age=zeros(Int64, n_samples), n_rebuild=zeros(Int64, n_samples))

    Threads.@threads for i in ProgressBar(1:n_samples)
        pool_res=check_result()
        for p = 1:n_pools
            ss = sample(1:nrow(drive_surv), n_drives; replace=true,ordered=true)
            fl = check_fail(drive_surv[ss,:], n_raid, time_window)
            if p == 1
                pool_res = fl
            elseif fl.fail && ((pool_res.fail && fl.fail_day<pool_res.fail_day) || !pool_res.fail)
                    pool_res = fl
            else
                pool_res.n_rebuild += fl.n_rebuild
                if pool_res.fail_day > fl.fail_day
                    pool_res.fail_day = fl.fail_day
                end
            end
        end

        results[i,:] = (pool_res.fail, pool_res.fail_day, pool_res.n_rebuild)
    end


    failed = subset(results,:failed)
    # get the minimum censored time
    mean_time_to_failure = mean(failed.age)
    pct_failed     = mean(results.failed)
    pct_rebuild    = mean(results.n_rebuild .> 1 )
    median_rebuild = median(results.n_rebuild)

    return (pct_failed*100.0, pct_rebuild*100.0, median_rebuild, mean_time_to_failure, results)
end

# simulating on real example 
# how to split 40 drives:

simulations  = DataFrame(
    n_drives =  [9, 9, 9, 9],
    n_raid   =  [2, 2, 2, 2],
    n_pools  =  [1, 2, 3, 4]
)


simulations_results = DataFrame(
    n_pools=Int[],
    n_drives=Int[],
    n_raid=Int[],
    pct_failed=Float64[],
    pct_rebuild=Float64[],
    median_rebuild=Float64[],
    mean_time_to_failure=Float64[],
)

time_window = 10       # days
n_samples = 100_000_000 # number of simulations


all_fits = DataFrame(
    age=Int[], 
    survival=Float64[],
    survival_min=Float64[],
    survival_max=Float64[],
    conf=String[],
    model = String[],
    n_drives= Int[],
    n_raid = Int[],
    n_pools = Int[]
    )


if false

# survival curves for the baseline data

fit_km_bl  = fit(KaplanMeier,drive_surv.age, drive_surv.FAIL)
conf_km_bl = reinterpret(reshape,Float64,confint(fit_km_bl))

    single_fit = DataFrame(
        age=fit_km_bl.times, 
        survival=fit_km_bl.survival*100,
        survival_min=conf_km_bl[1,:]*100,
        survival_max=conf_km_bl[2,:]*100,
    )

    single_fit[!,:conf] .= "1x$(model)"
    single_fit[!,:model] .= model
    single_fit[!,:n_drives] .= 1
    single_fit[!,:n_raid] .= 0
    single_fit[!,:n_pools] .= 1

    global all_fits = vcat(all_fits, single_fit)
end

for i=1:nrow(simulations)

    (pct_failed,pct_rebuild,median_rebuild,mean_time_to_failure, results)=
        simulate_raid(drive_surv, n_samples,simulations.n_pools[i], simulations.n_drives[i], simulations.n_raid[i], time_window)

    push!(simulations_results, (simulations.n_pools[i], simulations.n_drives[i], simulations.n_raid[i],pct_failed,pct_rebuild,median_rebuild,mean_time_to_failure))

    # buld K-M fit
    fit_km = fit(KaplanMeier,results.age, results.failed)
    conf_km = reinterpret(reshape,Float64,confint(fit_km))

    fits = DataFrame(
        age=fit_km.times, 
        survival=fit_km.survival*100,
        survival_min=conf_km[1,:]*100,
        survival_max=conf_km[2,:]*100,
    )
    
    fits[!,:conf] .= "$(simulations.n_drives[i])x$(model) RaidZ$(simulations.n_raid[i]) x $(simulations.n_pools[i]) pool(s)"
    fits[!,:model] .= model
    fits[!,:n_drives] .= simulations.n_drives[i]
    fits[!,:n_raid] .= simulations.n_raid[i]
    fits[!,:n_pools] .= simulations.n_pools[i]
        
    global all_fits = vcat(all_fits, fits)
end



p = plot(all_fits,
       x=:age, 
       y=:survival,
       ymin=:survival_min, 
       ymax=:survival_max, 
       color=:conf,
    Theme(alphas=[0.8],background_color="white"),
    Guide.xlabel("Age [days]"),
    Guide.ylabel("Survival probability [%]"),
    Guide.colorkey(title="Configuration "),
    Geom.line,Geom.ribbon )

p |> PNG("bootstrap_40_drives_$(model).png",8inch,6inch,dpi=200)


if false
# failed = subset(s,:failure => ByRow(x->x==1),:age => ByRow(x->x<=min_censored_age)).age
raid_z2_raid_z3 = subset(all_fits,:n_raid => ByRow(x->x>=2))
#@info raid_z2_raid_z3
# cutoff at 1000 days?

p = plot(raid_z2_raid_z3,
       x=:age, 
       y=:survival,ymin=:survival_min, ymax=:survival_max, 
       color=:conf,
    Theme(alphas=[0.8],background_color="white"),
    Guide.xlabel("Age [days]"),
    Guide.ylabel("Survival probability [%]"),
    Guide.colorkey(title="Configuration "),

    Geom.line,Geom.ribbon )

p |> PNG("bootstrap_pools_$(model)_raid_z2_z3.png",8inch,6inch,dpi=200)
#    @info "Failed: $(pct_failed*100)% Rebuilds: $(pct_rebuild*100)% Median rebuild drives: $(median_rebuild)"

end
println(simulations_results)
