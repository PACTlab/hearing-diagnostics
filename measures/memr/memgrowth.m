function y = memgrowth(x, params)
% A growth function to represent MEMR growth
%

a = params(1);
b = params(2);
c = params(3);
t = params(4);


y = b./(1 + exp(-1*a*(x - t))) + c;