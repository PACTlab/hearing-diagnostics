function [val, fitted] = memfit(x, y)

a = 0.2:0.1:1; % Slope parameter

% Note that we are allowing for the sigmoid to not plateu within the 34-88
% dB range. Thus, the upper limit of the plateu is set to be high.
b = 0:0.2:12; % Value at which the growth curve plateus


% Baseline should be close to zero 
c = 0:.01:0.1; % Basline paramater 


t = 52:3:136; % X-axis location parameter
% (this is the elicitor level at which the MEMR is halfway between c and b)

% Brute force optimization by least L1 norm
na = numel(a);
nb = numel(b);
nc = numel(c);
nt = numel(t);

err = inf*ones(na, nb, nc, nt);
for ka = 1:na
    for kb = 1:nb
        for kc = 1:nc
            for kt = 1:nt
                    params = [a(ka), b(kb), c(kc), t(kt)];
                    ypred = memgrowth(x, params);
                    err(ka,kb,kc,kt) = nansum(abs(y - ypred));
            end
        end
    end
end


[val, ind] = min(err(:));
[oa, ob, oc, ot] = ind2sub([na, nb, nc, nt], ind);
fitted = [a(oa), b(ob), c(oc), t(ot)];

