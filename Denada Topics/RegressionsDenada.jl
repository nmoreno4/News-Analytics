using DataFrames, Statistics, CSV, StatsBase

chosenVars = ["permno", "date","retadj"]
topics = ["AAA", "ACCI", "ALLCE", "BACT", "BKRFIG", "BKRT", "BONS", "BOSS1",
          "BUYB", "CASE1", "CEO1", "CFO1", "CHAIR1", "CLASS", "CM1", "CMPNY",
          "CNSL", "CORGOV", "CPROD", "DBTR", "DDEAL", "DEAL1", "DIV", "DVST",
          "FIND1", "FINE1", "HOSAL", "IPO", "LAYOFS", "LIST1", "MEET1", "MNGISS",
          "MONOP", "MRG", "NAMEC", "PRES1", "PRIV", "RECLL",
          "REORG", "RES", "RESF", "SHRACT", "SISU", "SL1", "SPLITB",
          "STAT", "STK", "XPAND", "ALL"]
