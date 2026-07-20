function y = memgrowthinv(x, params)
% Inverse of the growth function
%

a = params(1);
b = params(2);
c = params(3);
t = params(4);


y = t - (1/a)*log(b./(x-c) - 1);

y(x > b) = 106;
y(y > 105) = 106;