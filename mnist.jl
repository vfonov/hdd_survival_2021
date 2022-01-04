using Flux
using CUDA


using MLDatasets: MNIST
using Flux.Data: DataLoader
using Flux.Optimise: Optimiser, WeightDecay
using Flux: onehotbatch, onecold
using Flux.Losses: logitcrossentropy

using Logging

# load MNIST dataset
train_x, train_y = MNIST.traindata(Float32)
test_x, test_y = MNIST.testdata(Float32)

# reshape to use 1 channel , i.e 28x28x1xZZZ

train_x = reshape(train_x, 28, 28, 1, :)
test_x = reshape(test_x, 28, 28, 1, :)

# one-hot encoder
train_y, test_y = onehotbatch(train_y, 0:9), onehotbatch(test_y, 0:9)

# LeNet5 "constructor". 
# The model can be adapted to any image size
# and any number of output classes.
function LeNet5(; imgsize=(28,28,1), nclasses=10) 
    out_conv_size = (imgsize[1]÷4 - 3, imgsize[2]÷4 - 3, 16)
    
    return Chain(
            Conv((5, 5), imgsize[end]=>6, relu),
            MaxPool((2, 2)),
            Conv((5, 5), 6=>16, relu),
            MaxPool((2, 2)),
            flatten,
            Dense(prod(out_conv_size), 120, relu), 
            Dense(120, 84, relu), 
            Dense(84, nclasses)
          )
end

loss(ŷ, y) = logitcrossentropy(ŷ, y)

model = LeNet5() |> gpu

η = 3e-4             # learning rate
λ = 0                # L2 regularizer param, implemented as weight decay
batchsize = 256      # batch size
epochs = 100          # number of epochs
seed = 0             # set seed > 0 for reproducibility
use_cuda = true      # if true use cuda (if available)
infotime = 1 	     # report every `infotime` epochs
checktime = 5        # Save the model every `checktime` epochs. Set to 0 for no checkpoints.
tblogger = true      # log training with tensorboard
savepath = "runs/"    # results path

# load into DataLoader
data_loader = DataLoader((train_x, train_y), batchsize=batchsize, shuffle=true)



opt = ADAM(η)
if  λ>0
    opt = Optimiser(WeightDecay(λ), opt)
end
ps = Flux.params(model)

@info "Start Training"
for epoch in 1:epochs
    @info "Epoch:$(epoch)"
    # go over batches
    for (x, y) in data_loader
        #@assert size(x) == (28, 28, 1, 128) || size(x) == (28, 28, 1, 96)
        #@assert size(y) == (10, 128) || size(y) == (10, 96)
        
        x, y = x |> gpu, y |> gpu

        gs = Flux.gradient(ps) do
            ŷ = model(x)
            loss(ŷ, y)
        end

        Flux.Optimise.update!(opt, ps, gs)
    end

end
