import requests
from lxml import html
from bs4 import BeautifulSoup

startURLs = ["https://www.glassdoor.com/Reviews/Abila-Reviews-E815044.htm",
			 "https://www.glassdoor.com/Reviews/ADB-Airfield-Solutions-Reviews-E14062.htm"]

### Create connection session ###
session_requests = requests.session()
payload = {
	"username": "Rigonico",
	"password": "Nicolas44",
}
login_url = "https://www.glassdoor.com/profile/login_input.htm"
result = session_requests.get(login_url, headers={'User-Agent': 'Mozilla/5.0'})
result = session_requests.post(
	login_url,
	data = payload,
	headers = {'User-Agent': 'Mozilla/5.0', 'referer': login_url}
)


url = startURLs[1]
result = session_requests.get(
	url,
	headers = {'User-Agent': 'Mozilla/5.0', 'referer': url}
)

soup = BeautifulSoup(result.text, 'lxml')
# print(soup)
a = soup.findAll("li", {"class": "empReview"})

nRev = 0
time = a[nRev].findAll('time', {'class':'date'})[0]['datetime']
summary = a[nRev].findAll('span', {'class':'summary'})[0].text
jobTitle = a[nRev].findAll('span', {'class':'authorJobTitle'})[0].text
authorLocation = a[nRev].findAll('span', {'class':'authorLocation'})
