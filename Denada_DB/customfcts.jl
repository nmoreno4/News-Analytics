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

function CSdownload(daterange = ["01/01/2016", "12/31/2017"], CSvariables = "gvkey, datadate, cusip, conm, atq, ceqq, ibq, ltq, revtq, saleq, seqq, txditcq, xintq, exchg, pstkq, pstkrq, pstknq", datatable = "comp.fundq")
    @rput daterange
    @rput CSvariables
    @rput datatable
    print("hey")
    R"wrds <- DBI::dbConnect(RPostgres::Postgres(),
                      host='wrds-pgdata.wharton.upenn.edu',
                      port=9737,
                      user='mlam',
                      password='M@riel@mbertu193807',
                      sslmode='require',
                      dbname='wrds')"
    R"print(paste(\"SELECT\", CSvariables,
                            \"FROM\", datatable,
                            \"WHERE indfmt='INDL'
                              and datafmt='STD'
                              and popsrc='D'
                              and consol='C'
                              and datadate between '\", daterange[1], \"' and '\", daterange[2], \"'\"))"
    R"res <- DBI::dbSendQuery(wrds, paste(\"SELECT\", CSvariables,
                            \"FROM\", datatable,
                            \"WHERE indfmt='INDL'
                              and datafmt='STD'
                              and popsrc='D'
                              and consol='C'
                              and datadate between '\", daterange[1], \"' and '\", daterange[2], \"'\"))"
    print("lol")
    R"compustat <- DBI::dbFetch(res, n=-1)"
    R"DBI::dbClearResult(res)"
    R"DBI::dbDisconnect(wrds)"
    @rget compustat
    return compustat
end


function CRSPdownload(daterange = ["01/01/2016", "12/31/2017"],
            CRSPvariables = "a.permno, a.permco, a.date, b.shrcd, b.exchcd, a.ret,
                             a.retx, a.shrout, a.prc, a.vol, a.spread",
            datatable = ["crsp.msf", "crsp.msenames"])
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


function cumcount(X)
    res = Array{Int,1}(undef,length(X))
    for i = 1:length(X)
        res[i] = i-1
    end
    return res
end

function countmissing(X)
    return count(i->ismissing(i), X)
end

val2missing(v,mv) = mv >= v ? missing : v



function mergepermnopermco!(df)
    # Get sum and maximum for all permnos in a permco at a given date
    @time a = by(df, [:date, :permco]) do pdf
      DataFrame(sum_me = sum(pdf[:me]), max_me = maximum(pdf[:me]))
    end
    print(size(a,1))
    # prepare to drop permnos with lower me
    rename!(a, :max_me => :me)
    # drop permnos with lower me
    @time df = join(df, a, on = [:date, :permco, :me], kind = :inner)
    # drop this :me column which was just used to match the correct permnos
    delete!(df, [:me]); delete!(a, [:me]);
    # prepare to assign total me
    rename!(a, :sum_me => :me)
    #assign total me
    @time df = join(df, a, on = [:date, :permco], kind = :inner)
    return df
end


function groupcumret!(df, groupvar, myvar)
    a = by(df, groupvar) do pdf
      DataFrame(cumret = cumprod(pdf[myvar].+1))
    end
    df[Symbol("cum$(myvar)")] = a[:cumret]
    return df
end

function grouplag!(df, groupvar, myvar, nlags)
    a = by(df, groupvar) do pdf
      DataFrame(lag = lag(pdf[myvar], nlags))
    end
    df[Symbol("lag$(myvar)_$(nlags)")] = a[:lag]
    return df
end

function setfirstlme!(df, groupvar=:permno, myvar=:lagme_1)
    # First value of group is me/(1+retx)
    a = by(df, groupvar) do pdf
      DataFrame(firstlme = [pdf[:me][1]/(pdf[:retx][1]+1) ; pdf[myvar][2:end]])
    end
    df[myvar] = a[:firstlme]
    return df
end

function firstdiff(X)
    return [missing; X[2:end]-X[1:end-1]]
end
