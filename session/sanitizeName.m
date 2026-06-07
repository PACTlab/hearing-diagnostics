function s = sanitizeName(str)
    s = strrep(str, ' ', '');
    s = strrep(s, '/', '-');
    s = strrep(s, '\', '-');
    s = regexprep(s, '[^a-zA-Z0-9_-]', '');
end