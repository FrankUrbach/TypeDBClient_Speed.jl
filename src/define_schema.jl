using TypeDBClient: delete_database, create_database, contains_database, define, commit, transaction, CoreSession, Proto

function delete_db_create_db(client::TypeDBClient.AbstractCoreClient, database_name::String)
    if contains_database(client, database_name)
        delete_database(client, database_name)
    end
    create_database(client, database_name)

    sess = CoreSession(client, database_name , Proto.Session_Type.SCHEMA, request_timout=Inf)
    trans = transaction(sess, Proto.Transaction_Type.WRITE)

    define_string = read(open("typedb_defines/disease-netowrk-schema.gql"), String)

    define(trans, define_string)

    commit(trans)
    close(sess)
end
