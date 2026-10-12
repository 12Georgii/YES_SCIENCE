function dV = DiffVoltage(V)
dV = zeros(208,1);
for i = 1:16
    dv = diff([V(i,:),V(i,1)]);
    dv = dv(~circshift([ones(1,3),zeros(1,13)],i-2));
    dV(13*(i-1)+(1:13)) = dv;
end
end