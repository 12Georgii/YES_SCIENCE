function [rho,Zo] = transform(D)
    rho = D(:,1);
    N = length(rho);
    Zo = zeros(N,208);
    
    for i = 1:N
        Zo(i,:) = OmitCurrentAndRotate(D(i,2:end));
    end
end

function Z=OmitCurrentAndRotate(Z_wc)
    Z = zeros(208,1);
    for i = 1:16
        z = Z_wc(16*(i-1)+(1:16));
        z = circshift(z,1-i);
        Z(13*(i-1)+(1:13)) = z(3:15);
    end
end