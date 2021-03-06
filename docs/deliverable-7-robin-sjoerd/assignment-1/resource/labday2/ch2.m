function [h_est] = ch2(x, y,L_hat)
%USAGE
%creates channel estimate by Matched Filter
%input x and y vector 
%input L_hat:
%   - specifies L 
%       or
%   - can be set to 0 to use default length for L: 
%       L = length(y)-length(x)+1
if L_hat == 0
    L =length(y)-length(x)+1;
else
    L = L_hat;
end
%THIS METHOD DOES NOT WORK FOR SHORT SEQUENCES
xr = flipud(x);
h_est = filter(xr,1,y);
h_est=h_est(end-L:end);
alpha =x'*x;
h_est=h_est/alpha;


% %% plot the channel estimate
% figure
% plot_channel_estimate(h_est,'n','$$\hat{h}$$[n]','Recovered channel estimate using matched filter');
end
