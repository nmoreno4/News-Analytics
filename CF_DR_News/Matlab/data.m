a = fileread('/home/nicolas/Data/Input data/june1972dec2017.csv');
datacell = textscan( a, '%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f%f', 'delimiter', ',', 'HeaderLines', 1);
Duration = datacell{1};
Input = datacell{1};
YourTable = table(Duration, Input);