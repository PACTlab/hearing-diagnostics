function makeNoiseChip(parent, labelStr, valueStr, col)
p = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', 'w');
p.Layout.Row    = 1;
p.Layout.Column = col;
g = uigridlayout(p, [2 1]);
g.RowHeight       = {'1x', '1x'};
g.Padding         = [0 0 0 0];
g.RowSpacing      = 2;
g.BackgroundColor = 'w';
lbl = uilabel(g, 'Text', labelStr, 'FontSize', 9, ...
    'FontColor', [0.55 0.55 0.55]);
lbl.Layout.Row    = 1;
lbl.Layout.Column = 1;
val = uilabel(g, 'Text', valueStr, 'FontSize', 13, 'FontWeight', 'bold');
val.Layout.Row    = 2;
val.Layout.Column = 1;
end