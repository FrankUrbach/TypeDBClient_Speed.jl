# How to run:
#    julia --project=. scripts/parallel.jl
#
# To use a different batch size, set environment variable:
#    export BATCH_SIZE=1000
#    julia --project=. scripts/parallel.jl

using Distributed
using TypeDBClient


@info "Delete database biograkn, create it again and define the schema"
rootdir = joinpath(@__DIR__, "..")
include("$rootdir/src/define_schema.jl")

TypeDBClient.dbconnect("127.0.0.1") do client
    delete_db_create_db(client, "biograkn")
end


@info "Preparing worker processes"
addprocs(21)
@everywhere rootdir = joinpath(@__DIR__, "..")
@everywhere import Pkg
@everywhere Pkg.activate(rootdir)
@everywhere ENV["BATCH_SIZE"] = 1000
@everywhere include("$rootdir/src/load_dataset.jl")

@info "Loading data to all worker processes"
@everywhere queries = make_queries(load_data())

@info "Loading function in master process"
include("$rootdir/src/load_dataset.jl")

@everywhere batch_size = get_env_batch_size()
@info "Batch size = $(get_env_batch_size())"

@info "Warming up"
@time try
    parallel_run()
catch ex
    @info "Got exception... be brave, just continue!"
end

@info "Test runs"
@time parallel_run()
@time parallel_run()
