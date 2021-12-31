using Flux, Metalhead

model = ResNet50()

using Flux: onehotbatch

batchsize = 8
data = [(rand(Float32, 224, 224, 3, batchsize), onehotbatch(rand(1:1000), 1:1000))
        for _ in 1:3]
opt = ADAM()
ps = Flux.params(model)
loss(x, y, m) = Flux.Losses.logitcrossentropy(m(x), y)
for (i, (x, y)) in enumerate(data)
    @info "Starting batch $i ..."
    gs = gradient(() -> loss(x, y, model), ps)
    Flux.update!(opt, ps, gs)
end


