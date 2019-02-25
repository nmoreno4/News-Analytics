using HTTP, Gumbo, Cascadia
mozHeaders = [string(k) => string(v) for (k,v) in [("User-Agent", "Mozilla/5.0")]]
loginData = [string(k) => string(v) for (k,v) in [("username", "Rigonico"), ("password", "Nicolas44")]]
login_url = "https://www.glassdoor.com/profile/login_input.htm"
@time r = HTTP.request("POST", login_url, mozHeaders, loginData)
HTTP.request("POST", login_url, [], "post body data")


https://www.glassdoor.com/profile/login_input.htm?userOriginHook=HEADER_SIGNIN_LINK
username
ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=
vzPVK3owWGtd49JZdDwtbA:sGR5AsPNy8C_SOhSxbQnkIkACAmtir3qFbuanCu1Q_EU_JCusQHkLEcfmJ4qR4xvJDWLNkvDs6AMS8ml1sKm1A:4p_iSQVcPtAmCYyMMi7F0DI50I-NUHkREMy90cZfYDs
password
6Lej8UwUAAAAANV3V5Ow5gJo2-pHj9p5ko8igIe


using PyCall

py"""
import requests
from lxml import html
session_requests = requests.session()
payload = {
	"username": "Rigonico",
	"password": "Nicolas44",
	"publicKeyForUserAuth": "6Lej8UwUAAAAANV3V5Ow5gJo2-pHj9p5ko8igIe-"
}
login_url = "https://www.glassdoor.com/profile/login_input.htm"
result = session_requests.get(login_url, headers={'User-Agent': 'Mozilla/5.0'})
result = session_requests.post(
	login_url,
	data = payload,
	headers = {'User-Agent': 'Mozilla/5.0', 'referer': login_url}
)
url = "https://glassdoor.com/Reviews/J-P-Morgan-Reviews-E145.htm"
result = session_requests.get(
	url,
	headers = {'User-Agent': 'Mozilla/5.0', 'referer': url}
)
from bs4 import BeautifulSoup
soup = BeautifulSoup(result.text, 'lxml')
# print(soup)
a = soup.findAll("li", {"class": "empReview"})

nRev = 0
time = a[nRev].findAll('time', {'class':'date'})[0]['datetime']
summary = a[nRev].findAll('span', {'class':'summary'})[0].text
jobTitle = a[nRev].findAll('span', {'class':'authorJobTitle'})[0].text
authorLocation = a[nRev].findAll('span', {'class':'authorLocation'})

"""

py"""
print(a[nRev].findAll('span', {'class':'authorJobTitle'}))
"""

@time @progress for i in 1:1111111
	"Love u"
end

py"""
nRev=0
summary = a[nRev].findAll('span', {'class':'summary'})
jobTitle = a[nRev].findAll('span', {'class':'authorJobTitle'})[0].text
authorLocation = a[nRev].findAll('span', {'class':'authorLocation'})
print(authorLocation)
"""
