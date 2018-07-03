%% NEWS AND BETAS AT MARKET LEVEL!--------------------
%RUN INDEPENDENTLY FROM SECTION ABOVE!!!!!!!
clc;clear;
load('pitfalls_datarx2016.mat')
pitfallsi=pitfalls_datarx;
ind_beg=find(pitfallsi(:,1)==196306);
ind_end=find(pitfallsi(:,1)==201606);

state_variables=pitfallsi(ind_beg:ind_end,2:5);

for k=1:size(state_variables,2)
    
VAR_system=regstats((state_variables(2:end,k)),state_variables(1:end-1,:));

ols_coeff(:,k)=VAR_system.beta;
ols_tstat(:,k)=VAR_system.tstat.t;
ols_se(:,k)=VAR_system.tstat.se;
ols_resid(:,k)=VAR_system.r;
ols_adjR2(:,k)=VAR_system.adjrsquare;

clear VAR_system

end

coeffs=ols_coeff'; tstats=ols_tstat'; adjR2=[0;ols_adjR2']; std_errors=ols_se';

% nCF and nDR computation
clear nCF nDR varCF var DR twocov covar varrMe risk composition cov

rho=0.996 %0.997 for Tolga; 
lambda=rho*coeffs(:,2:end)*(eye(k)-rho*coeffs(:,2:end))^(-1);

e1=[1;0;0;0]; mapDR=e1'*lambda;
C =(1/length(ols_resid))*(ols_resid'*ols_resid); CC=cov(ols_resid);

nCF=(e1'+e1'*lambda)*ols_resid'; nDR=e1'*lambda*ols_resid';

varCF=var(nCF); varDR=var(nDR); twocov=2*cov(nCF,nDR);

varrMe=varCF+varDR-twocov(2,1); covar=cov(nCF,nDR);
risk_composition1=[varCF varCF/varrMe;varDR varDR/varrMe;-twocov(2,1) -twocov(2,1)/varrMe;varrMe varrMe/CC(1,1)];
news_flow=[pitfalls_datarx(ind_beg+1:ind_end,1) nCF' nDR'];