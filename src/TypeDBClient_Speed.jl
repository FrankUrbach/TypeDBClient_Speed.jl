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

        start_preparing = time()
        query_strings = String[]
        data_pair = Pair[]
        for row in eachrow(df)
            tmp_string = "insert \$a isa protein, has uniprot-id \"$(row[1])\", has uniprot-name \"$(row[4])\";"
            push!(query_strings, tmp_string)
            push!(data_pair, (row[1]=>row[4]))
        end
        end_preparing = time()

        @info "Time for preparing: $(end_preparing - start_preparing)"

        sess = g.CoreSession(client, database_name , g.Proto.Session_Type.DATA, request_timout=Inf)

        time1 = time()
        if make_inserts
            res_insert = insert_data(sess, query_strings, 2000)
        end
        time2 = time()

        @info "Uniprot took $(round(time2 - time1, digits = 2)) seconds"

        return res_insert
end

function transaction_insert(trans::g.AbstractCoreTransaction, data, count_channel::Channel, nr_channel)
    count_transactions = length(trans.session.transactions)
    @info "Channel Nr: $nr_channel is open. Transactions open: $count_transactions"
    for str in data
        g.insert(trans, str)
    end
    g.commit(trans)
    put!(count_channel, nr_channel)
end

function insert_data(session::g.AbstractCoreSession, data::Vector{String}, intervall::Int64 = 100)
    ranges = divid_into_intervals(data, intervall)
    length_ranges = length(ranges)
    @info "Length ranges $(length_ranges)"
    count_channel = Channel(length_ranges + 1)

    tmp_sess = session
    tmp_client = session.client
    for i in 1:length_ranges
        if i % 4 == 0
            tmp_client = g.CoreClient("127.0.0.1", 1729)
            tmp_sess = g.CoreSession(tmp_client, database_name , g.Proto.Session_Type.DATA, request_timout=Inf)
        end
        trans_in = g.transaction(tmp_sess, g.Proto.Transaction_Type.WRITE)
        @async transaction_insert(trans_in, ranges[i], count_channel,i)
    end

    for _ in 1:length_ranges
       tmp = take!(count_channel)
       @info "Task $tmp is ready"
    end

    return true
end
