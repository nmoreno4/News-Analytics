from pymongo import MongoClient
client = MongoClient()
client = MongoClient('localhost', 27017)
db = client.NewsDB
companies = db.Companies
bills_post = companies.find_one()
print(bills_post)
