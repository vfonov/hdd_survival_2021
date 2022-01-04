using Turing
using Optim
using StatsBase
using Turing: Variational

@model function gdemo()
    s ~ InverseGamma(2,3)
    m ~ Normal(0, sqrt(s))

    1.5 ~ Normal(m, sqrt(s))
    2.0 ~ Normal(m, sqrt(s))

    return m, s
end

model = gdemo()
@info model
# Use the default optimizer, LBFGS.
mle1 = optimize(model, MLE())
@info mle1

mpa1 = optimize(model, MAP())
@info mpa1

# Use a specific optimizer.
#mle2 = optimize(model, MLE(), Optim.Newton())
#mpa2 = optimize(model, MAP(), Optim.Newton())

#@info mle1
#@info mle2