NS = importNS("/home/nicolas/Data/TS/NS/ALL/ALL_all_VW_day.csv");
X = rmmissing(NS.NS);
hpX=hpfilter(X,16660);
figure(1)
plot(hpX)
figure(2)
plot(X)

[AF, sy] = HamiltonMod(4,hpX',2)
figure(3)
plot(AF)
figure(4)
plot(sy)