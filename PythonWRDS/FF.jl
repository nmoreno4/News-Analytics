using PyCall
@pyimport wrds
@pyimport pandas as pd
@pyimport numpy as np
@pyimport datetime as dt
@pyimport psycopg2
@pyimport matplotlib.pyplot as plt
@pyimport dateutil.relativedelta as drel
# @pyimport scipy.stats
@pyimport pandas.tseries.offsets as pdoffs

db = wrds.Connection(wrds_username = "mlam")

comp = db[:raw_sql]("select gvkey, datadate, at, pstkl, txditc,pstkrv, seq, pstk from comp.funda where indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C' and datadate >= '01/01/2014'")

comp["datadate"]=pd.to_datetime(comp["datadate"]) #convert datadate to date fmt
comp["year"]=comp["datadate"][:dt][:year]

# create preferrerd stock
comp = comp[:assign](ps=np.where(comp["pstkrv"][:isnull](), comp["pstkl"], comp["pstkrv"]))
comp = comp[:assign](ps=np.where(comp["ps"][:isnull](),comp["pstk"], comp["ps"]))
comp = comp[:assign](ps=np.where(comp["ps"][:isnull](),0,comp["ps"]))

comp["txditc"]=comp["txditc"].fillna(0)

# create book equity
comp = comp[:assign](be=comp["seq"]+comp["txditc"]-comp["ps"])
comp = comp[:assign](be=np.where(comp["be"]>0, comp["be"], np.nan))

# number of years in Compustat
comp = comp[:sort_values](by=["gvkey","datadate"])
comp = comp[:assign](count=comp[:groupby](["gvkey"])[:cumcount]())

comp=comp[["gvkey","datadate","year","be","count"]]
