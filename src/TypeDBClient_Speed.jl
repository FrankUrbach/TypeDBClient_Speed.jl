using TypeDBClient
using DataFrames
using CSV
using Profile
using ProfileSVG
using ProfileView
using Dates

using TypeDBClient: AbstractCoreSession,
                    CoreClient,
                    CoreSession,
                    AbstractCoreTransaction,
                    Proto,
                    commit,
                    insert

include("define_schema.jl")
include("utils.jl")

database_name = "biograkn"

client = CoreClient("127.0.0.1",1729)

delete_db_create_db(client, database_name)
@info "Deleted all databases, create database $database_name and the schema"

function uniprot(client::TypeDBClient.AbstractCoreClient, database_name::String, make_inserts::Bool=true)
    # Uniprot
        @info "1. Uniprot"
        df = CSV.File(joinpath(@__DIR__, "../dataset/uniprot/uniprot.csv"), delim="\t") |> DataFrame

        start_preparing = time()
        query_strings = String[]
        data_pair = Pair[]
        for row in eachrow(df)
            tmp_string = " \$_ isa protein, has uniprot-id \"$(row[1])\", has uniprot-name \"$(row[4])\";"
            push!(query_strings, tmp_string)
            push!(data_pair, (row[1]=>row[4]))
        end
        end_preparing = time()

        @info "Time for preparing: $(end_preparing - start_preparing)"

        sess = CoreSession(client, database_name , Proto.Session_Type.DATA, request_timeout=Inf)


        time1 = time()
        if make_inserts
            res_insert = insert_data(sess, query_strings, 100, 50)
        end
        time2 = time()

        @info "Uniprot took $(round(time2 - time1, digits = 2)) seconds"

        return res_insert
end

function transaction_insert(trans::AbstractCoreTransaction,
            data,
            count_channel::Channel,
            nr_channel,
            error_channel::Channel)

    count_transactions = length(trans.session.transactions)
    @info "Channel Nr: $nr_channel is open. Transactions open: $count_transactions"
    for strings in data
        ins_str = "insert \n" * join(strings, "\n")
        res = insert(trans, ins_str)
        if isempty(res)
            @async put!(error_channel, ins_str)
            @info ins_str
        end
    end
    commit(trans)
    put!(count_channel, nr_channel)
end

function insert_data(session::AbstractCoreSession,
            data::Vector{String},
            intervall::Int64 = 100,
            sub_intervall::Int64 = 50)

    ranges = collect(Iterators.partition(Iterators.partition(data, sub_intervall), intervall))

    length_ranges = length(ranges)
    @info "Length ranges $(length_ranges)"

    count_channel = Channel(10)
    error_channel = Channel(10)
    err_queries = String[]

    for i in 1:length_ranges
        tmp_client = CoreClient("127.0.0.1", 1729)
        tmp_session = CoreSession(tmp_client, database_name , Proto.Session_Type.DATA, request_timeout=Inf, error_time = 20)
        trans_in = transaction(tmp_session, Proto.Transaction_Type.WRITE)
        @async transaction_insert(trans_in, ranges[i], count_channel, i, error_channel)
    end

    @async begin
        while isopen(error_channel)
            yield()
            if isready(error_channel)
                push!(err_queries, take!(error_channel))
            end
        end
    end

    for _ in 1:length_ranges
       tmp = take!(count_channel)
       @info "Task $tmp is ready"
    end

    return err_queries
end

rest = uniprot(client, database_name)
