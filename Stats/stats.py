
from pymongo import MongoClient
from bson.son import SON
import pprint
import pandas as pd
from datetime import datetime
db = MongoClient().NewsDB
df = pd.DataFrame()
for y in range(2003,2017):
    start = datetime(y,1, 1)
    end = datetime(y+1,1,1)
    pipeline = [
             {"$match" : { "date" : { '$gte' : start, '$lt' : end } } },
             {"$group": {"_id": "$ptf_2by3_size_value", "FFI48_desc":{"$addToSet" : "$FFI48_desc"}}},
             {"$project":{"portfolio":"$_id","_id":0,"count":{"$size":"$FFI48_desc"}}}
             ]
    a=list(db.CRSPmonthly.aggregate(pipeline))
    print(a)
    e = pd.DataFrame([[i['portfolio'], i['count']] for i in a])
    df[y] = e

with open("aggreg.csv", 'a') as f:
     d.to_csv(f, header=False)
     
     
     
     
from pymongo import MongoClient
from bson.son import SON
import pprint
import pandas as pd
import numpy as np
from datetime import datetime
db = MongoClient().NewsDB
for ptf in ["HH", "LH", "HL", "LL"]:
    res = np.zeros([48, len(range(2003,2017))])
    yid = -1
    for y in range(2003,2017):
        yid+=1
        start = datetime(y,1, 1)
        end = datetime(y+1,1,1)
        pipeline = [
                 {"$match" : { "date" : { '$gte' : start, '$lt' : end }, "ptf_2by3_size_value" : ptf } },
                 {"$group": {"_id": "$FFI48", "PERMNO":{"$addToSet" : "$PERMNO"}}},
                 {"$project":{"portfolio":"$_id","_id":0,"count":{"$size":"$PERMNO"}}}
                 ]
        a=list(db.CRSPmonthly.aggregate(pipeline))
        for i in a:
            if isinstance(i['portfolio'], (int, float)):
                print(yid)
                res[int(i['portfolio']-1), yid] = i['count']
            
    print(res)
    df = pd.DataFrame(res)
    with open("aggreg.csv", 'a') as f:
         df.to_csv(f, header=False)




from pymongo import MongoClient
from bson.son import SON
import pprint
import pandas as pd
import numpy as np
from datetime import datetime
db = MongoClient().NewsDB
for ptf in ["HH", "LH", "HL", "LL"]:
    res = np.zeros([48, len(range(2003,2017))])
    yid = -1
    for y in range(2003,2017):
        yid+=1
        start = datetime(y,1, 1)
        end = datetime(y+1,1,1)
        pipeline = [
                 {"$match" : { "firstCreated" : { '$gte' : start, '$lt' : end } } },
                 {"$group": {"_id": "$takes.analytics.ptf_2by3_size_value", "averageQuantity": { "$avg": "$takes.analytics.sentimentNegative" }}}
                 ]
        a=list(db.News.aggregate(pipeline))
        print(a)
        for i in a:
            if isinstance(i['portfolio'], (int, float)):
                print(yid)
                res[int(i['portfolio']-1), yid] = i['count']
            
    print(res)
    df = pd.DataFrame(res)
    with open("sentNeg.csv", 'a') as f:
         df.to_csv(f, header=False)
