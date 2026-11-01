function makeInfoChip(parent, labelStr, valueStr, col)
% Check if chip already exists and update, otherwise create
existing = findobj(parent, 'Tag', sprintf('chip_val_%d', col));
if ~isempty(existing)
    existing.Text = valueStr;
    return
end

p = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', 'w');
p.Layout.Row    = 1;
p.Layout.Column = col;
g = uigridlayout(p, [2 1]);
g.RowHeight       = {'1x', '1x'};
g.Padding         = [0 2 0 2];
g.RowSpacing      = 0;
g.BackgroundColor = 'w';
lbl = uilabel(g, 'Text', labelStr, 'FontSize', 9, ...
    'FontColor', [0.55 0.55 0.55]);
lbl.Layout.Row = 1; lbl.Layout.Column = 1;
val = uilabel(g, 'Text', valueStr, 'FontSize', 12, ...
    'FontWeight', 'bold', 'Tag', sprintf('chip_val_%d', col));
val.Layout.Row = 2; val.Layout.Column = 1;
end