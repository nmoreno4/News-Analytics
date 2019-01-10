NS = importNS("/home/nicolas/Data/TS/NS/ALL/ALL_all_VW_quarter.csv");
X = rmmissing(NS.NS);
load Data_GDP
hpX=hpfilter(X,6.75);
figure(1)
plot(hpX)
figure(2)
plot(X)

[AF, sy] = HamiltonMod(8,Data',4)
figure(3)
plot(AF)
figure(4)
plot(sy)