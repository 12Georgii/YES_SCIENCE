function P = Perimeter(mdl)
% calculates perimeter
     V = sum(get_elem_volume(mdl))
     H = range(mdl.nodes(:,3))
     S_tors = V/H
     S_tot = TotalArea(mdl)
     P = (S_tot - 2*S_tors)/H

end

function S = TotalArea(mdl)

    v1 = mdl.nodes(mdl.boundary(:,2),:) - mdl.nodes(mdl.boundary(:,1),:);
    v2 = mdl.nodes(mdl.boundary(:,3),:) - mdl.nodes(mdl.boundary(:,1),:);
    c = cross(v1, v2, 2);
    S = 0.5 * sum(sqrt(sum(c.^2, 2)));
end

