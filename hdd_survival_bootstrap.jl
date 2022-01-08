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



@info "Maximum drive age:$(maximum(drive_surv.age)/365)y N=$(nrow(drive_surv))"

# return (n_fail,n_rebuild)
function check_fail(s,n_raid,time_window)
    failed = subset(s,:failure => ByRow(x->x==1)).age
    n_rebuild = length(failed)

    if n_rebuild == 0
        return (0,0)
    elseif  n_rebuild < n_raid
        return (0, n_rebuild)
    else
        failed = sort(failed)
        n_fail=0
        for n=1:(length(failed)-n_raid)
            if (failed[n+n_raid]-failed[n])<time_window
                n_fail = 1
                break
            end
        end
        return (n_fail, n_rebuild)
    end
end


function run_simulation(drive_surv, n_samples, n_drives, n_raid, time_window)

    results = zeros(Int32, n_samples, 2)
    for i in ProgressBar(1:n_samples)
        ss = sample(1:nrow(drive_surv), n_drives, replace=false)
        fl = check_fail( drive_surv[ss,:],n_raid,time_window)
        results[i,:] .= fl
    end

    pct_failed  = mean(results[:,1])
    pct_rebuild = mean(results[:,2] .> 1 )
    median_rebuild = median(results[:,2])

    return (pct_failed*100.0, pct_rebuild*100.0, median_rebuild)
end

simulations = DataFrame(
    n_drives=[9,10,11],
    n_raid=[1,2,3],

    pct_failed=[0.0,0.0,0.0],
    pct_rebuild=[0.0,0.0,0.0], 
    median_rebuild=[0.0,0.0,0.0]   
)

time_window = 4 # days
n_samples = 1_000_000 # number of simulations

for i=1:nrow(simulations)
    (simulations.pct_failed[i], simulations.pct_rebuild[i], simulations.median_rebuild[i]) = 
        run_simulation(drive_surv, n_samples, simulations.n_drives[i], simulations.n_raid[i], time_window)
end

#    @info "Failed: $(pct_failed*100)% Rebuilds: $(pct_rebuild*100)% Median rebuild drives: $(median_rebuild)"

println(simulations)