using DataFrames
using Distributions
using Logging
using Statistics
using Bootstrap
using ProgressBars

include("Backblaze.jl")
using .Backblaze

model = "ST12000NM0007"

drive_surv = backblaze_drive_surv(model)
censored_drive_surv = subset(drive_surv,:failure => ByRow(x->x==1))
@info "Maximum drive age:$(maximum(drive_surv.age)/365)y N=$(nrow(drive_surv))"
@info "Median censored age:$(median(censored_drive_surv.age)/365)y"


# return (n_fail,n_rebuild)
function check_fail(s,n_raid,time_window)
    # return (failed,age,n_rebuid)
    censored = subset(s,:failure => ByRow(x->x==0)).age
    min_censored_age = minimum(censored)

    failed = subset(s,:failure => ByRow(x->x==1),:age => ByRow(x->x<=min_censored_age)).age
    n_rebuild = length(failed)

    if n_rebuild == 0
        return (0, min_censored_age, 0)
    elseif  n_rebuild < n_raid
        return (0, min_censored_age, n_rebuild)
    else
        failed = sort(failed)
        if failed[end] > min_censored_age # we don't actually know, because non-failed drives got censored earlier
            return (0, min_censored_age, 0)
        else
            fail = 0
            fail_day = failed[1]
            for n=1:(length(failed)-n_raid)
                if (failed[n+n_raid]-failed[n])<time_window
                    fail = 1
                    fail_day = failed[n+n_raid]
                    break
                end
            end
            return (1, fail_day, n_rebuild)
        end
    end
end


function simulate_raid(drive_surv, n_samples, n_drives, n_raid, time_window)
    results = DataFrame(failed=zeros(Int32, n_samples), age=zeros(Int32, n_samples), n_rebuild=zeros(Int32, n_samples))

    for i in ProgressBar(1:n_samples)
        ss = sample(1:nrow(drive_surv), n_drives, replace=false)
        results[i,:] = check_fail(drive_surv[ss,:],n_raid,time_window)
    end

    failed = subset(results,:failed => ByRow(x->x==1))
    # get the minimum censored time
    mean_time_to_failure = mean(failed.age)
    pct_failed     = mean(results.failed)
    pct_rebuild    = mean(results.n_rebuild .> 1 )
    median_rebuild = median(results.n_rebuild)


    return (pct_failed*100.0, pct_rebuild*100.0, median_rebuild,mean_time_to_failure)
end

simulations = DataFrame(
    n_drives=[8,9,10,11],
    n_raid=[0,1,2,3],

    pct_failed=[0.0,0.0,0.0,0.0],
    pct_rebuild=[0.0,0.0,0.0,0.0], 
    median_rebuild=[0.0,0.0,0.0,0.0],
    mean_time_to_failure=[0.0,0.0,0.0,0.0],
)

time_window = 4       # days
n_samples = 1_000_000 # number of simulations

for i=1:nrow(simulations)
    simulations[i,[:pct_failed,:pct_rebuild,:median_rebuild,:mean_time_to_failure]]=
        simulate_raid(drive_surv, n_samples, simulations.n_drives[i], simulations.n_raid[i]+1, time_window)
end

#    @info "Failed: $(pct_failed*100)% Rebuilds: $(pct_rebuild*100)% Median rebuild drives: $(median_rebuild)"

println(simulations)
