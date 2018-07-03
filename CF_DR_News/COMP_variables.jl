using CSV, Missings, DataFrames

compustat = @time readtable("/home/nicolas/Data/WRDS/e1a1f0f65c5d898c.csv")
CRSP = @time readtable("/home/nicolas/Data/WRDS/b00b0503c73fae04.csv")
links = @time readtable("/home/nicolas/Data/WRDS/da4a5fd8a39de2a3.csv")
portfolio_data = @time readtable("/home/nicolas/Data/CRSPComp.csv")
linked_data = @time readtable("/home/nicolas/Data/WRDS/quarterly 1961 compustat merged.csv")

PERMNOs = Set(portfolio_data[:PERMNO])
permnoBis = Set(linked_data[:LPERMNO])

crtgvkey = -999
permnoMap = Dict()
permnos = []
cusips = []
permcos = []
comnams = []
for row in 1:size(links,1)
  if links[:gvkey][row] == crtgvkey
    if links[:LPERMNO][row] in PERMNOs
      if !ismissing(links[:LPERMCO][row]) && (links[:LINKPRIM][row] in ["C", "P"]) && (links[:LINKTYPE][row] in ["LU", "LC"])
        push!(permcos, links[:LPERMCO][row])
      end
      if !ismissing(links[:LPERMNO][row]) && (links[:LINKPRIM][row] in ["C", "P"]) && (links[:LINKTYPE][row] in ["LU", "LC"])
        push!(permnos, links[:LPERMNO][row])
      end
      if !ismissing(links[:cusip][row]) && (links[:LINKPRIM][row] in ["C", "P"]) && (links[:LINKTYPE][row] in ["LU", "LC"])
        push!(cusips, links[:cusip][row])
      end
      if !ismissing(links[:conm][row]) && (links[:LINKPRIM][row] in ["C", "P"]) && (links[:LINKTYPE][row] in ["LU", "LC"])
        push!(comnams, links[:conm][row])
      end
    end
  else
    if row>1
      permnoMap[crtgvkey] = Dict("PERMNO" => permnos, "PERMCO" => permcos, "CUSIPS" => cusips, "COMNAM" => comnams)
    end
    crtgvkey = links[:gvkey][row]
    if ismissing(links[:LPERMCO][row]) || !(links[:LPERMNO][row] in PERMNOs) || !(links[:LINKPRIM][row] in ["C", "P"]) || !(links[:LINKTYPE][row] in ["LU", "LC"])
      permcos = []
    else
      permcos = [links[:LPERMCO][row]]
    end
    if ismissing(links[:LPERMNO][row]) || !(links[:LPERMNO][row] in PERMNOs) || !(links[:LINKPRIM][row] in ["C", "P"]) || !(links[:LINKTYPE][row] in ["LU", "LC"])
      permnos = []
    else
      permnos = [links[:LPERMNO][row]]
    end
    if ismissing(links[:cusip][row]) || !(links[:LPERMNO][row] in PERMNOs) || !(links[:LINKPRIM][row] in ["C", "P"]) || !(links[:LINKTYPE][row] in ["LU", "LC"])
      cusips = []
    else
      cusips = [links[:cusip][row]]
    end
    if ismissing(links[:conm][row]) || !(links[:LPERMNO][row] in PERMNOs) || !(links[:LINKPRIM][row] in ["C", "P"]) || !(links[:LINKTYPE][row] in ["LU", "LC"])
      comnams = []
    else
      comnams = [links[:conm][row]]
    end
  end
end

permnolength = []
permcolength = []
cc = 0
for i in permnoMap
  push!(permnolength, length(Set(i[2]["PERMNO"])))
  push!(permcolength, length(Set(i[2]["PERMCO"])))
end
single = 0
double = 0
zeroes = 0
for i in permnolength
  if i==0
    zeroes += 1
  elseif i == 1
    single+=1
  else
    double+=1
  end
end

permnoTOgvkey = Dict()
gvkeyTOpermno = Dict()
cc = 0
for i in permnoMap
  if length(i[2]["PERMNO"])==1
    if i[2]["PERMNO"][1] in PERMNOs
      cc+=1
      try print("$(permnoTOgvkey[i[2]["PERMNO"][1]]) \n") catch print("") end
      permnoTOgvkey[i[2]["PERMNO"][1]] = i[1]
      gvkeyTOpermno[i[1]] = i[2]["PERMNO"][1] #(i[2]["PERMNO"][1], i[2]["COMNAM"][1], i[2]["PERMCO"][1], i[2]["CUSIPS"][1])
# Note : I have stocks where I have 2 gvkeys for a given PERMNO. The Cusip is also different. PERMCO seems to remain identical though.
    end
  end
end

# Make sure indfmt='INDL' and datafmt='STD' and popsrc='D' and consol='C'
# if missing(TXDITC) then TXDITC = 0 ;

SEQq = compustat[:seqq]
TXDITCq = Missings.coalesce.(compustat[:txditcq],0)
PSq = Missings.coalesce.(compustat[:pstkrq],compustat[:pstkq]) #what about pstkl? use pstkn?
BEq = SEQq + TXDITCq - PSq

b = idxMap(compustat[:gvkey])
c = idxMap(compustat[:datadate])

#Order to find previous date
IBq = compustat[:ibq]
roe=IBq/((BEq+lag(BEq))/2)

#Join CRSP and Compustat


retM = CRSP[:RET]
dlretM = CRSP[:DLRET]
prcM = CRSP[:PRC]
shroutM = CRSP[:SHROUT]
retadj = sum(Missings.skip.(retM),1).*sum(Missings.skip(1,dlret))-1
abs(a.prc)*a.shrout


function countMissing(X)
  cc = 0
  for i in X
    if ismissing(i)
      cc+=1
    end
  end
  return cc/length(X)
end

function idxMap(X)
  idMap = Dict()
  cc = 0
  for row in X
    cc+=1
    if row in keys(idMap)
      push!(idMap[row], cc)
    else
      if !(ismissing(row))
        idMap[row] = [cc]
      end
    end
  end
  return idMap
end
