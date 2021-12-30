# Import Turing and Distributions.

using Turing, Distributions
# Import RDatasets.
using RDatasets

# Import MCMCChains, Plots, and StatsPlots for visualizations and diagnostics.
using MCMCChains, Plots, StatsPlots

df = dataset("HSAUR","mastectomy")
