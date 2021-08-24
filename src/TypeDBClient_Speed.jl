using TypeDBClient
using DataFrames
using CSV
using BenchmarkTools
using Profile
using ProfileSVG
using ProfileView
using Dates


g = TypeDBClient

include("define_schema.jl")
include("utils.jl")

database_name = "biograkn"

client = g.CoreClient("127.0.0.1",1729)

delete_all_dbs_create_db(client, database_name)
@info "Deleted all databases, create database $database_name and the schema"

function uniprot(client::TypeDBClient.AbstractCoreClient, database_name::String, make_inserts::Bool=true)
    # Uniprot
        @info "1. Uniprot"
        df = CSV.File(joinpath(@__DIR__, "../dataset/uniprot/uniprot.csv"), delim="\t") |> DataFrame

        query_strings = String[]

        start_preparing = time()
        data_pair = Pair[]
        for row in eachrow(df)
            tmp_string = "insert \$a isa protein, has uniprot-id \"$(row[1])\", has uniprot-name \"$(row[4])\";"
            push!(query_strings, tmp_string)
            push!(data_pair, (row[1]=>row[4]))
        end
        end_preparing = time()

        # @info "Time for preparing: $(end_preparing - start_preparing)"

        sess = g.CoreSession(client, database_name , g.Proto.Session_Type.DATA, request_timout=Inf)

        if make_inserts
            start_insert = time()
               res_insert = insert_data(sess, query_strings, 1000)
            end_insert = time()
            @info "Uniprot in $(end_insert - start_insert) s"
        end
        return res_insert
end

function transaction_insert(trans::g.AbstractCoreTransaction, inp_channel::Channel, count_channel::Channel, nr_channel)
    @info "Channel Nr: $nr_channel is open"
    while isopen(inp_channel)
        yield()
        if isready(inp_channel)
            tmp_vector = take!(inp_channel)
            for str in tmp_vector
                g.insert(trans, str)
            end
            put!(count_channel, 1)
        end
    end
    g.commit(trans)
    @info "Transaction channel Nr: $nr_channel commited"
end

function insert_data(session::g.AbstractCoreSession, data::Vector{String}, intervall::Int64 = 100)
    ranges = divid_into_intervals(data, intervall)
    length_ranges = length(ranges)
    @info "Length ranges $(length_ranges)"
    inp_channel = Channel(1000)
    count_channel = Channel(10)

    count_fullfilled_range = 0
    @info "Made input channel"
    # make worker

    for i in 1:23
        tmp_trans = g.transaction(session, g.Proto.Transaction_Type.WRITE)
        @async transaction_insert(tmp_trans, inp_channel, count_channel,i)
    end

    @info "Made worker"
    # divide the work
    for ran in ranges
        if isopen(inp_channel)
            put!(inp_channel, ran)
        else
            throw("channel closed")
        end
    end
    while count_fullfilled_range < length_ranges
        if isopen(count_channel)
            if isready(count_channel)
                count_fullfilled_range += take!(count_channel)
            end
        end
    end
    close(inp_channel)
end

times = uniprot(client, database_name, true)

# for i in 2:length(times)
#     @info round(times[i] - times[i-1], digits=2)
# end
