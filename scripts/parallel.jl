# How to run:
#    julia --project=. scripts/parallel.jl

using Distributed

@everywhere rootdir = joinpath(@__DIR__, "..")
@everywhere import Pkg
@everywhere Pkg.activate(rootdir)
@everywhere include("$rootdir/src/load_dataset.jl")
@everywhere queries = make_queries(load_data())
@everywhere batch_size = 500

@info "Loading function in master process"
include("$rootdir/src/load_dataset.jl")

@info "Warming up"
@time try
    parallel_run()
catch ex
    @info "Got exception... be brave, just continue!"
end

@info "Test run"
@time parallel_run()
