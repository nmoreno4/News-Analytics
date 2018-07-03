module WRDSdownload

using RCall, DataFrames
@rlibrary RPostgres
@rlibrary DBI

export CSdownload, CRSPdownload, linktabledownload, delistdownload, gatherWRDSdata, FF_factors_download

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


function CSdownload(daterange = ["01/01/2016", "12/31/2017"], CSvariables = "gvkey, datadate, cusip, conm, atq, ceqq, ibq, ltq, revtq, saleq, seqq, txditcq, xintq, exchg, pstkq, pstkrq, pstknq", datatable = "comp.fundq")
    @rput daterange
    @rput CSvariables
    @rput datatable
    R"wrds <- DBI::dbConnect(RPostgres::Postgres(),
                      host='wrds-pgdata.wharton.upenn.edu',
                      port=9737,
                      user='mlam',
                      password='M@riel@mbertu193807',
                      sslmode='require',
                      dbname='wrds')"
    R"res <- DBI::dbSendQuery(wrds, paste(\"SELECT\", CSvariables,
                            \"FROM\", datatable,
                            \"WHERE indfmt='INDL'
                              and datafmt='STD'
                              and popsrc='D'
                              and consol='C'
                              and datadate between '\", daterange[1], \"' and '\", daterange[2], \"'\"))"
    R"compustat <- DBI::dbFetch(res, n=-1)"
    R"DBI::dbClearResult(res)"
    R"DBI::dbDisconnect(wrds)"
    @rget compustat
    return compustat
end


function CRSPdownload(daterange = ["01/01/2016", "12/31/2017"], CRSPvariables = "a.permno, a.permco, a.date, b.shrcd, b.exchcd, a.ret, a.retx, a.shrout, a.prc, a.vol, a.spread", datatable = ["crsp.msf", "crsp.msenames"])
    @rput daterange
    @rput CRSPvariables
    @rput datatable
    R"wrds <- DBI::dbConnect(RPostgres::Postgres(),
                      host='wrds-pgdata.wharton.upenn.edu',
                      port=9737,
                      user='mlam',
                      password='M@riel@mbertu193807',
                      sslmode='require',
                      dbname='wrds')"
    R"res <- DBI::dbSendQuery(wrds, paste(\"SELECT\", CRSPvariables, \"FROM\", datatable[1], \"as a left join\", datatable[2], \"as b on a.permno=b.permno and b.namedt<=a.date and a.date<=b.nameendt WHERE date between '\", daterange[1], \"' and '\", daterange[2], \"'and b.exchcd between 1 and 3\"))"
    R"CRSP <- DBI::dbFetch(res, n=-1)"
    R"DBI::dbClearResult(res)"
    R"DBI::dbDisconnect(wrds)"
    @rget CRSP
    return CRSP
end

function linktabledownload()
    R"wrds <- DBI::dbConnect(RPostgres::Postgres(),
                      host='wrds-pgdata.wharton.upenn.edu',
                      port=9737,
                      user='mlam',
                      password='M@riel@mbertu193807',
                      sslmode='require',
                      dbname='wrds')"
    R"res <- DBI::dbSendQuery(wrds, \"SELECT gvkey, lpermno as permno, linktype, linkprim, linkdt, linkenddt FROM crsp.ccmxpf_linktable where substr(linktype,1,1)='L' and (linkprim ='C' or linkprim='P')\")"
    R"linktable <- DBI::dbFetch(res, n=-1)"
    R"DBI::dbClearResult(res)"
    R"DBI::dbDisconnect(wrds)"
    @rget linktable
    return linktable
end

function delistdownload(freq="m")
    R"wrds <- DBI::dbConnect(RPostgres::Postgres(),
                      host='wrds-pgdata.wharton.upenn.edu',
                      port=9737,
                      user='mlam',
                      password='M@riel@mbertu193807',
                      sslmode='require',
                      dbname='wrds')"
    if freq=="m"
        R"res <- DBI::dbSendQuery(wrds, \"SELECT permno, dlret, dlstdt
                               FROM crsp.msedelist\")"
    elseif freq=="d"
        R"res <- DBI::dbSendQuery(wrds, \"SELECT permno, dlret, dlstdt
                               FROM crsp.dsedelist\")"
   end
    R"delist <- DBI::dbFetch(res, n=-1)"
    R"DBI::dbClearResult(res)"
    R"DBI::dbDisconnect(wrds)"
    @rget delist
    return delist
end


function gatherWRDSdata()
    CSvariables = "gvkey, datadate, cusip, conm, atq, ceqq, ibq, ltq, revtq, saleq, seqq, txditcq, xintq, exchg, pstkq, pstkrq, pstknq"
    CRSPvariables = "permno, exchcd, ticker, comnam, permco, prc, vol, ret, shrout, spread, retx"
    @rput CSvariables
    R"wrds <- DBI::dbConnect(RPostgres::Postgres(),
                      host='wrds-pgdata.wharton.upenn.edu',
                      port=9737,
                      user='mlam',
                      password='M@riel@mbertu193807',
                      sslmode='require',
                      dbname='wrds')"
    R"res <- RPostgres::dbSendQuery(wrds, \"SELECT gvkey, datadate, cusip, conm, atq, ceqq, ibq, ltq, revtq, saleq, seqq, txditcq, xintq, exchg, pstkq, pstkrq, pstknq
                              FROM comp.fundq
                              WHERE indfmt='INDL'
                                and datafmt='STD'
                                and popsrc='D'
                                and consol='C'
                                and datadate >= '01/01/2015'\")"
    R"compustat <- dbFetch(res, n=-1)"
    R"dbClearResult(res)"
    R"res <- dbSendQuery(wrds, \"SELECT a.permno, a.permco, a.date, b.shrcd, b.exchcd, a.ret, a.retx, a.shrout, a.prc, a.vol, a.spread
                              FROM crsp.msf as a
                              left join crsp.msenames as b
                              on a.permno=b.permno
                              and b.namedt<=a.date
                              and a.date<=b.nameendt
                              WHERE date between '01/01/1959' and '12/31/2017'
                              and b.exchcd between 1 and 3\")"
    R"CRSP <- dbFetch(res, n=-1)"
    R"dbClearResult(res)"
    R"res <- dbSendQuery(wrds, \"SELECT *
                                 FROM crsp.ccmxpf_linktable\")"
    R"linktable <- dbFetch(res, n=-1)"
    R"dbClearResult(res)"
    R"res <- dbSendQuery(wrds, \"SELECT permno, dlret, dlstdt
                                 FROM crsp.msedelist\")"
    R"delist <- dbFetch(res, n=-1)"
    R"DBI::dbClearResult(res)"
    R"DBI::dbDisconnect(wrds)"
    @rget linktable
    @rget compustat
    @rget CRSP
    @rget delist

    return (compustat, CRSP, delist, linktable)
    end

end #module
