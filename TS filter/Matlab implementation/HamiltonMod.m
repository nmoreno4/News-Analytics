
function[AngularFreq, SY] = HamiltonMod(h,data,interval)
 
 %Danger!! data vector must be (1xT)
 
 T = length(data);
 m = (-h:h);
 
 f = (h+1-abs(m))./((h+1).^2); %(1 x 2h+1) %%%% kernel
 
 J = (0:1:(T-1)/2);
 n = length(J);
 
 % Compute sy estimator (non-capital)
 
 MT1 = (data*cos((2*pi/T).*(0:T-1)'*J)).^2; 
 MT2 = (data*sin((2*pi/T).*(0:T-1)'*J)).^2;
 
 sy = (1/(2*pi*T)).*(MT1+MT2);  %(1 x m)
 sy = sy';
 %  Compute SY estimator (capital)
 
 
 for j = 1:n    
     
     low = -h+j;
   upper =  h+j;
     
     if  low <= 0
       %  SY(j)= f*[zeros(h-j+1,1);sy(1:h+j)];
        Z = zeros(1,h-j+1);
        [a b] =size(Z);
        SY(j)= ([Z  f(b+1:end)]/sum([Z  f(b+1:end)]))*[zeros(h-j+1,1);sy(1:h+j)];
%         SY(j)= ([Z  f(b+1:end)])*[zeros(h-j+1,1);sy(1:h+j)];
     elseif  upper > n 
         r = upper-n;
        SY(j)= ([f(1:2*h+1-r) zeros(1,r)]/sum([f(1:2*h+1-r) zeros(1,r)]))*[sy(-h+j:end);zeros(r,1)];
        
     else
         SY(j)= f*sy(-h+j:h+j);
     end
     
 end
     
  SY;
 
%  plot(2*pi*J/(T*interval),SY,'r')
%  xlim([0, 5])
 AngularFreq = 2*pi*J/(T*interval);
 SY;
 
 
 
 
  
 
 
 
 