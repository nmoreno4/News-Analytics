#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri May 25 07:54:04 2018

@author: nicolas
"""

import pandas as pd
import numpy as np
from pymongo import MongoClient
from bson.son import SON
from datetime import datetime
import pprint

a = pd.read_csv("/CECI/home/ulg/affe/nmoreno/permnoToPermId.csv", header = -1)
b = a.values
permnos = b[0,:]
permids = b[1,:]
ystart=2002
yend =2017
db = MongoClient().NewsDB
df = pd.DataFrame()
res = np.chararray(shape=(yend-ystart,len(permids)), unicode=True, itemsize=2)
pid = -1


for permno in permnos:
    pid+=1
    yid = -1
    for y in range(ystart,yend):
        yid+=1
        start = datetime(y,7, 1)
        end = datetime(y+1,7,1)
        doc = db.CRSPmonthly.find_one({"date" : { '$gte' : start, '$lt' : end }, "PERMNO" : permno})
        if doc is not None:
            res[yid, pid] = doc["ptf_2by3_size_value"]
            
df =  pd.DataFrame(res)

permids[0]

pid=-1
for permid in permids:
    pid+=1
    yid = -1
    for y in range(ystart,yend):
        yid+=1
        start = datetime(y,7, 1)
        end = datetime(y+1,7,1)
        print(permid)
#        pprint.pprint(db.News.find_one({"takes.analytics.assetId": str(permid)[0:-2], "firstCreated" : { '$gte' : start, '$lt' : end }}))
        db.News.update_many({"takes.analytics.assetId": str(permid)[0:-2], 
                             "firstCreated" : { '$gte' : start, '$lt' : end }}, 
                            {"$push": {"takes.$[].analytics.$[].ptf_2by3_size_value": res[yid, pid]}}
                            )
    


#with open("map_perm.csv", 'a') as f:
#    df.to_csv(f, header=False)

