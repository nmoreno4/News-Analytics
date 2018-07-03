using PyCall, DataFrames, Conda, JLD2
@pyimport wrds
# username:mlam
# password:M@riel@mbertu193807
db = wrds.Connection()
print(db[:describe_table](library="comp", table="fundq"))
comp = db[:raw_sql]("select gvkey, datadate, atq, txditcq,
                    seqq
                    from comp.fundq
                    where indfmt='INDL'
                    and datafmt='STD'
                    and popsrc='D'
                    and consol='C'
                    and datadate >= '01/01/1959'")
# print(get(comp))
# data = hcat(get(comp, "datadate"), get(comp, "gvkey"), get(comp, "atq"))
# print(convert(Array{Any}, get(comp, "datadate")))
a = convert(PyAny, get(comp, "datadate"))
print(typeof(a))

b = convert(PyAny, comp)
print(typeof(b))
@save "/home/nicolas/test.jld2" a
@save "/home/nicolas/testb.jld2" b
