using PyCall
@pyimport pymongo
client = pymongo.MongoClient()
db = client[:NewsDB]
collection = db[:copyflatstockdate]
c = collection[:find_one]()
