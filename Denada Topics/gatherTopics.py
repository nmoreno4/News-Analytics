import timeit
import pymongo
import datetime

client = pymongo.MongoClient()
db = client["Jan2019"]
collection = db["PermnoDay"]
query = {"td": {"$gte": 1}, "gsector":{"$ne": "40"}, "nS_nov24H_0_rel100": {"$lte": 100}}
retvalues = {"date":1, "permno":1, "retadj":1, "ranksize":1, "nS_nov24H_0_rel100":1, "posSum_nov24H_0_rel100":1, "negSum_nov24H_0_rel100":1}
cursor = collection.find(query, retvalues)
starttime = datetime.datetime.now()
b = list(cursor)
len(b)
b[10000]
print(datetime.datetime.now()-starttime)
