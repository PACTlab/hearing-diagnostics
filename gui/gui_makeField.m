function field = gui_makeField(parent, labelStr, row, col, type, default)
p = uipanel(parent, 'BorderType', 'none', 'BackgroundColor', 'w');
p.Layout.Row    = row;
p.Layout.Column = col;
g = uigridlayout(p, [2 1]);
g.RowHeight       = {16, '1x'};
g.Padding         = [0 0 0 0];
g.RowSpacing      = 2;
g.BackgroundColor = 'w';
lbl = uilabel(g, 'Text', labelStr, 'FontSize', 10, ...
    'FontColor', [0.45 0.45 0.45]);
lbl.Layout.Row    = 1;
lbl.Layout.Column = 1;
switch type
    case 'edit'
        field = uieditfield(g, 'text', 'Value', default);
    case 'drop'
        field = uidropdown(g, 'Items', default);
end
field.Layout.Row    = 2;
field.Layout.Column = 1;
end