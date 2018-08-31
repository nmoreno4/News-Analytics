using RCall, DataFrames
@rlibrary RPostgres
@rlibrary DBI

function FF_factors_download(daterange = ["01/01/2016", "12/31/2017"], datatable = "FACTORS_DAILY")
    #or FACTORS_MONTHLY
    @rput daterange
    @rput datatable
    R"wrds <- DBI::dbConnect(RPostgres::Postgres(),
                      host='wrds-pgdata.wharton.upenn.edu',
                      port=9737,
                      user='mlam',
                      password='M@riel@mbertu193807',
                      sslmode='require',
                      dbname='wrds')"
    R"res <- DBI::dbSendQuery(wrds, paste(\"SELECT * FROM\", datatable,
                          \"WHERE date between '\", daterange[1], \"' and '\", daterange[2], \"'\"))"
    R"FFfactors <- DBI::dbFetch(res, n=-1)"
    R"DBI::dbClearResult(res)"
    R"DBI::dbDisconnect(wrds)"
    @rget FFfactors
    return FFfactors
end
