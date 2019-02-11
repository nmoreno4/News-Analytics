import timeit
import pymongo
import datetime
import pandas as pd

client = pymongo.MongoClient()
db = client["Jan2019"]
collection = db["PermnoDay"]
query = {"date": {"$lte": datetime.datetime(2003, 1, 31)}}
# query = {"td": {"$gte": 3750}}
retvalues = {"date":1, "permno":1, "retadj":1, "bemeY":1,  "retadj":1, "volume":1, "ebitda":1, "gsector":1, "me":1, "atY":1,
             "nS_nov24H_0_rel100":1, "posSum_nov24H_0_rel100":1, "negSum_nov24H_0_rel100":1,
             "nS_CMPNY_inc_nov24H_0_rel100":1, "posSum_CMPNY_inc_nov24H_0_rel100":1, "negSum_CMPNY_inc_nov24H_0_rel100":1,
             "nS_BACT_inc_nov24H_0_rel100":1, "posSum_BACT_inc_nov24H_0_rel100":1, "negSum_BACT_inc_nov24H_0_rel100":1,
             "nS_RES_inc_nov24H_0_rel100":1, "posSum_RES_inc_nov24H_0_rel100":1, "negSum_RES_inc_nov24H_0_rel100":1,
             "nS_RESF_inc_nov24H_0_rel100":1, "posSum_RESF_inc_nov24H_0_rel100":1, "negSum_RESF_inc_nov24H_0_rel100":1,
             "nS_MRG_inc_nov24H_0_rel100":1, "posSum_MRG_inc_nov24H_0_rel100":1, "negSum_MRG_inc_nov24H_0_rel100":1,
             "nS_MNGISS_inc_nov24H_0_rel100":1, "posSum_MNGISS_inc_nov24H_0_rel100":1, "negSum_MNGISS_inc_nov24H_0_rel100":1,
             "nS_DEAL1_inc_nov24H_0_rel100":1, "posSum_DEAL1_inc_nov24H_0_rel100":1, "negSum_DEAL1_inc_nov24H_0_rel100":1,
             "nS_DIV_inc_nov24H_0_rel100":1, "posSum_DIV_inc_nov24H_0_rel100":1, "negSum_DIV_inc_nov24H_0_rel100":1,
             "nS_AAA_inc_nov24H_0_rel100":1, "posSum_AAA_inc_nov24H_0_rel100":1, "negSum_AAA_inc_nov24H_0_rel100":1,
             "nS_FINE1_inc_nov24H_0_rel100":1, "posSum_FINE1_inc_nov24H_0_rel100":1, "negSum_FINE1_inc_nov24H_0_rel100":1,
             "nS_BOSS1_inc_nov24H_0_rel100":1, "posSum_BOSS1_inc_nov24H_0_rel100":1, "negSum_BOSS1_inc_nov24H_0_rel100":1,
             "nS_IPO_inc_nov24H_0_rel100":1, "posSum_IPO_inc_nov24H_0_rel100":1, "negSum_IPO_inc_nov24H_0_rel100":1,
             "nS_STAT_inc_nov24H_0_rel100":1, "posSum_STAT_inc_nov24H_0_rel100":1, "negSum_STAT_inc_nov24H_0_rel100":1,
             "nS_BUYB_inc_nov24H_0_rel100":1, "posSum_BUYB_inc_nov24H_0_rel100":1, "negSum_BUYB_inc_nov24H_0_rel100":1,
             "nS_ALLCE_inc_nov24H_0_rel100":1, "posSum_ALLCE_inc_nov24H_0_rel100":1, "negSum_ALLCE_inc_nov24H_0_rel100":1,
             "nS_DVST_inc_nov24H_0_rel100":1, "posSum_DVST_inc_nov24H_0_rel100":1, "negSum_DVST_inc_nov24H_0_rel100":1,
             "nS_SISU_inc_nov24H_0_rel100":1, "posSum_SISU_inc_nov24H_0_rel100":1, "negSum_SISU_inc_nov24H_0_rel100":1,
             "nS_REORG_inc_nov24H_0_rel100":1, "posSum_REORG_inc_nov24H_0_rel100":1, "negSum_REORG_inc_nov24H_0_rel100":1,
             "nS_CPROD_inc_nov24H_0_rel100":1, "posSum_CPROD_inc_nov24H_0_rel100":1, "negSum_CPROD_inc_nov24H_0_rel100":1,
             "nS_STK_inc_nov24H_0_rel100":1, "posSum_STK_inc_nov24H_0_rel100":1, "negSum_STK_inc_nov24H_0_rel100":1,
             "nS_CASE1_inc_nov24H_0_rel100":1, "posSum_CASE1_inc_nov24H_0_rel100":1, "negSum_CASE1_inc_nov24H_0_rel100":1,
             "nS_BKRT_inc_nov24H_0_rel100":1, "posSum_BKRT_inc_nov24H_0_rel100":1, "negSum_BKRT_inc_nov24H_0_rel100":1,
             "nS_MONOP_inc_nov24H_0_rel100":1, "posSum_MONOP_inc_nov24H_0_rel100":1, "negSum_MONOP_inc_nov24H_0_rel100":1,
             "nS_CLASS_inc_nov24H_0_rel100":1, "posSum_CLASS_inc_nov24H_0_rel100":1, "negSum_CLASS_inc_nov24H_0_rel100":1,
             "nS_CFO1_inc_nov24H_0_rel100":1, "posSum_CFO1_inc_nov24H_0_rel100":1, "negSum_CFO1_inc_nov24H_0_rel100":1,
             "nS_MEET1_inc_nov24H_0_rel100":1, "posSum_MEET1_inc_nov24H_0_rel100":1, "negSum_MEET1_inc_nov24H_0_rel100":1,
             "nS_CEO1_inc_nov24H_0_rel100":1, "posSum_CEO1_inc_nov24H_0_rel100":1, "negSum_CEO1_inc_nov24H_0_rel100":1,
             "nS_SHRACT_inc_nov24H_0_rel100":1, "posSum_SHRACT_inc_nov24H_0_rel100":1, "negSum_SHRACT_inc_nov24H_0_rel100":1,
             "nS_LIST1_inc_nov24H_0_rel100":1, "posSum_LIST1_inc_nov24H_0_rel100":1, "negSum_LIST1_inc_nov24H_0_rel100":1,
             "nS_LAYOFS_inc_nov24H_0_rel100":1, "posSum_LAYOFS_inc_nov24H_0_rel100":1, "negSum_LAYOFS_inc_nov24H_0_rel100":1,
             "nS_DBTR_inc_nov24H_0_rel100":1, "posSum_DBTR_inc_nov24H_0_rel100":1, "negSum_DBTR_inc_nov24H_0_rel100":1,
             "nS_DDEAL_inc_nov24H_0_rel100":1, "posSum_DDEAL_inc_nov24H_0_rel100":1, "negSum_DDEAL_inc_nov24H_0_rel100":1,
             "nS_SPLITB_inc_nov24H_0_rel100":1, "posSum_SPLITB_inc_nov24H_0_rel100":1, "negSum_SPLITB_inc_nov24H_0_rel100":1,
             "nS_CHAIR1_inc_nov24H_0_rel100":1, "posSum_CHAIR1_inc_nov24H_0_rel100":1, "negSum_CHAIR1_inc_nov24H_0_rel100":1,
             "nS_HOSAL_inc_nov24H_0_rel100":1, "posSum_HOSAL_inc_nov24H_0_rel100":1, "negSum_HOSAL_inc_nov24H_0_rel100":1,
             "nS_ACCI_inc_nov24H_0_rel100":1, "posSum_ACCI_inc_nov24H_0_rel100":1, "negSum_ACCI_inc_nov24H_0_rel100":1,
             "nS_XPAND_inc_nov24H_0_rel100":1, "posSum_XPAND_inc_nov24H_0_rel100":1, "negSum_XPAND_inc_nov24H_0_rel100":1}
baseret = {"date":1, "permno":1, "retadj":1, "bemeY":1,  "retadj":1, "volume":1, "ebitda":1, "gsector":1, "me":1, "atY":1}
cursor = collection.find(query, baseret)
starttime = datetime.datetime.now()
X = pd.DataFrame(list(cursor))
print(datetime.datetime.now()-starttime)
X.sum()
X.values
