function txt = rmcomment(txt)
charflag = false;

if ischar(txt)
    charflag = true;
    txt = {txt};
end

% delete section comment
% find %{ which has only blank between line starting and itself.
% then take all lines until
% find %} which has only blank between line starting and itself.
txt = cellfun(@(str) regexprep(str, '((^|\n)\s*%\{\s*\n([^\n]|\n)*?(\n\s*%\}))',''), txt, 'un', false);

% delete inline comments
% find % sign outside of the string
% how to find string?
% : surrounded by quotes (')
%     where the starting qute should not be next to 
%     alphanumeric, underscore, ), ] nor }.
txt = cellfun(@(str) regexprep(str, '((^|\n)[^''%\n]*(((?<!(\w|\.|\]|\)|\}))''[^''\n]*'')[^%\n]*)*)%[^\n]*', '$1'), txt, 'un', false);
% delete everything after line continuations
% find ... outside of the string
txt = cellfun(@(str) regexprep(str, '((^|\n)[^''\n]*(((?<!(\w|\.|\]|\)|\}))''[^''\n]*'')[^\n]*)*?)\.{3,}[^\n]*[\s]*', '$1'), txt, 'un', false);

% delete tailing white space
txt = cellfun(@(str) regexprep(str, '[^\S\n]+($|\n)', '$1'), txt, 'un', false);
% remove blank lines
txt = cellfun(@(str) regexprep(str, '\n+', '\n'), txt, 'un', false);
% if input was char
if charflag
    txt = txt{1};
end