function calBadge = gui_cal_badge(name, cal)

if isempty(cal)
    txt = sprintf('%s — none', name);
     badge_col = [1.0 0.95 0.88];
     font_col =  [0.52 0.31 0.05];

else
    txt = sprintf('%s ✓', name);
    badge_col = [0.88 0.96 0.93];
    font_col = [0.07 0.39 0.28];

end

calBadge.text = txt; 
calBadge.badgeColor = badge_col; 
calBadge.fontColor = font_col; 

end